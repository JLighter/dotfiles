# Tests du helper WireGuard. Sans dependance hors libnm :
#   python3 -I -B -m unittest discover -s tests -v
#
# NetworkManager n'est jamais joint : `nmcli`, la lecture des AllowedIPs et
# l'enregistrement libnm sont remplaces. Seule la construction de la connexion
# passe par la vraie libnm, qui ne parle pas au demon pour ca.
#
# Les cles sont tirees au hasard a chaque execution : aucune cle, meme factice,
# n'est ecrite dans le depot.
#
# Adapte de omarchy-wireguard (VirtualDataPro, MIT) : tests/test_backend.py.

import base64
import importlib.util
import os
import stat
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import call, patch

spec = importlib.util.spec_from_file_location(
    'wireguard_backend', Path(__file__).parents[1] / 'wireguard-backend.py')
backend = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backend)

TARGET = '11111111-1111-1111-1111-111111111111'
FULL_ACTIVE = '22222222-2222-2222-2222-222222222222'
SPLIT_ACTIVE = '33333333-3333-3333-3333-333333333333'
FULL_IDLE = '44444444-4444-4444-4444-444444444444'


def key():
    return base64.b64encode(os.urandom(32)).decode()


def config(extra_interface='', allowed='0.0.0.0/0, ::/0'):
    return (f'[Interface]\n{extra_interface}PrivateKey = {key()}\n'
            'Address = 10.0.0.2/32, fd00::2/128\nDNS = 1.1.1.1\n\n'
            f'[Peer]\nPublicKey = {key()}\nAllowedIPs = {allowed}\n'
            'Endpoint = vpn.example.com:51820\nPersistentKeepalive = 25\n')


def profile(identifier, active):
    return {'uuid': identifier, 'name': identifier[:4], 'active': active,
            'state': 'activated' if active else 'deactivated', 'device': '', 'counters': None}


# --- AC-WG-02 : liste des tunnels ---------------------------------------------

class ProfilesTests(unittest.TestCase):
    # Format reel de `nmcli -t -e yes -f UUID,TYPE,NAME,STATE,DEVICE connection
    # show` : un tunnel inactif a STATE et DEVICE vides.
    OUTPUT = (f'{TARGET}:wireguard:Travail\\: VPN\\\\bureau:activated:wg0\n'
              '55555555-5555-5555-5555-555555555555:802-3-ethernet:Filaire:activated:eno1\n'
              f'{FULL_IDLE}:wireguard:maison::\n')

    def test_ac_wg_02_lit_les_noms_echappes_et_ignore_les_autres_types(self):
        with patch.object(backend, 'nmcli', return_value=self.OUTPUT), \
                patch.object(backend, 'counters', return_value=None):
            rows = backend.profiles()
        self.assertEqual([row['uuid'] for row in rows], [FULL_IDLE, TARGET])
        self.assertEqual(rows[1]['name'], 'Travail: VPN\\bureau')
        self.assertEqual(rows[1]['device'], 'wg0')
        self.assertTrue(rows[1]['active'])

    def test_ac_wg_02_un_etat_vide_vaut_deactivated(self):
        with patch.object(backend, 'nmcli', return_value=self.OUTPUT), \
                patch.object(backend, 'counters', return_value=None):
            idle = backend.profiles()[0]
        self.assertEqual(idle['state'], 'deactivated')
        self.assertFalse(idle['active'])
        self.assertIsNone(idle['counters'])

    def test_ac_wg_02_les_compteurs_ne_sont_lus_que_pour_un_tunnel_actif(self):
        with patch.object(backend, 'nmcli', return_value=self.OUTPUT), \
                patch.object(backend, 'counters', return_value={'rx': 1, 'tx': 2}) as read:
            backend.profiles()
        read.assert_called_once_with('wg0')

    def test_ac_wg_n4_un_nom_d_interface_douteux_ne_touche_pas_sysfs(self):
        for device in ('../secrets', '..', '.', '', 'a' * 16, 'wg0/../../etc'):
            with patch.object(backend.Path, 'read_text') as read:
                self.assertIsNone(backend.counters(device), device)
                read.assert_not_called()


# --- AC-WG-N1 : actions sur un tunnel -----------------------------------------

class ActionGuardTests(unittest.TestCase):
    def test_ac_wg_n1_un_identifiant_qui_n_est_pas_un_uuid_est_refuse(self):
        for verb in ('up', 'down'):
            with patch.object(backend, 'nmcli') as command:
                with self.assertRaises(ValueError):
                    backend.main([verb, '$(touch /tmp/unwanted)'])
                command.assert_not_called()

    def test_ac_wg_n1_un_uuid_hors_liste_wireguard_est_refuse(self):
        for verb in ('up', 'down'):
            with patch.object(backend, 'profiles', return_value=[]), \
                    patch.object(backend, 'nmcli') as command:
                with self.assertRaises(ValueError):
                    backend.main([verb, TARGET])
                command.assert_not_called()

    def test_down_passe_l_uuid_en_argument_distinct(self):
        with patch.object(backend, 'profiles', return_value=[profile(TARGET, True)]), \
                patch.object(backend, 'nmcli') as command:
            self.assertEqual(backend.main(['down', TARGET]), {'ok': True})
        command.assert_called_once_with('connection', 'down', 'uuid', TARGET)

    def test_une_action_inconnue_est_refusee(self):
        with patch.object(backend, 'nmcli') as command:
            with self.assertRaises(ValueError):
                backend.main(['export', TARGET])
        command.assert_not_called()


# --- AC-WG-03 : un seul full tunnel a la fois ---------------------------------

class FullTunnelTests(unittest.TestCase):
    PROFILES = [profile(TARGET, False), profile(FULL_ACTIVE, True),
                profile(SPLIT_ACTIVE, True), profile(FULL_IDLE, False)]
    FULL = {TARGET, FULL_ACTIVE, FULL_IDLE}

    def run_up(self, full=None, nmcli_effect=None):
        full = self.FULL if full is None else full
        with patch.object(backend, 'profiles', return_value=self.PROFILES), \
                patch.object(backend, 'full_tunnels', side_effect=lambda ids: {i for i in ids if i in full}), \
                patch.object(backend, 'nmcli', side_effect=nmcli_effect) as command:
            try:
                return backend.main(['up', TARGET]), command
            except Exception as error:
                return error, command

    def test_ac_wg_03_une_route_par_defaut_fait_un_full_tunnel(self):
        self.assertTrue(backend.covers_default_route(['0.0.0.0/0']))
        self.assertTrue(backend.covers_default_route(['10.0.0.0/8', '::/0']))
        self.assertFalse(backend.covers_default_route(['10.0.0.0/8', '192.168.1.0/24']))
        self.assertFalse(backend.covers_default_route([]))

    def test_ac_wg_03_full_tunnels_lit_les_allowedips_des_profils_libnm(self):
        NM, _ = backend.libraries()
        full, _ = backend.build_tunnel(config(allowed='10.0.0.0/8, ::/0'), 'full')
        split, _ = backend.build_tunnel(config(allowed='10.0.0.0/8'), 'split')
        connections = {TARGET: full, SPLIT_ACTIVE: split}
        client = SimpleNamespace(get_connection_by_uuid=connections.get)
        fake = SimpleNamespace(Client=SimpleNamespace(new=lambda _: client),
                               SettingWireGuard=NM.SettingWireGuard)
        with patch.object(backend, 'libraries', return_value=(fake, None)):
            self.assertEqual(backend.full_tunnels([TARGET, SPLIT_ACTIVE, FULL_IDLE]), {TARGET})

    def test_ac_wg_03_activer_un_full_tunnel_coupe_d_abord_les_autres_full_actifs(self):
        result, command = self.run_up()
        self.assertEqual(result, {'ok': True, 'stopped': [FULL_ACTIVE]})
        self.assertEqual(command.call_args_list, [
            call('connection', 'down', 'uuid', FULL_ACTIVE),
            call('connection', 'up', 'uuid', TARGET)])

    def test_ac_wg_03_un_split_tunnel_ne_coupe_personne(self):
        result, command = self.run_up(full={FULL_ACTIVE, FULL_IDLE})
        self.assertEqual(result, {'ok': True, 'stopped': []})
        command.assert_called_once_with('connection', 'up', 'uuid', TARGET)

    def test_ac_wg_03_un_echec_d_activation_laisse_les_victimes_coupees(self):
        error, command = self.run_up(nmcli_effect=['', RuntimeError('refus')])
        self.assertIsInstance(error, backend.ActionError)
        self.assertEqual(error.stopped, [FULL_ACTIVE])
        # Pas de rollback : choix valide, comme omarchy-vpn.
        self.assertNotIn(call('connection', 'up', 'uuid', FULL_ACTIVE), command.call_args_list)

    def test_ac_wg_03_l_erreur_json_porte_les_tunnels_deja_coupes(self):
        error = backend.ActionError('Activation impossible', [FULL_ACTIVE])
        self.assertEqual(backend.error_payload(error),
                         {'error': 'Activation impossible', 'stopped': [FULL_ACTIVE]})

    def test_une_erreur_inattendue_ne_sort_qu_un_message_generique(self):
        payload = backend.error_payload(KeyError('PrivateKey = secret'))
        self.assertNotIn('secret', payload['error'])
        self.assertEqual(payload['stopped'], [])


# --- AC-WG-07 / AC-WG-N5 : renommer --------------------------------------------

class RenameTests(unittest.TestCase):
    def rename(self, identifier, name, known=None):
        known = [profile(TARGET, False)] if known is None else known
        with patch.object(backend, 'profiles', return_value=known), \
                patch.object(backend, 'nmcli') as command:
            try:
                return backend.rename(identifier, {'name': name}), command
            except ValueError as error:
                return error, command

    def test_ac_wg_07_renomme_par_l_uuid_avec_le_nom_nettoye(self):
        result, command = self.rename(TARGET, '  Travail: VPN  ')
        self.assertEqual(result, {'ok': True})
        command.assert_called_once_with('connection', 'modify', 'uuid', TARGET, 'connection.id', 'Travail: VPN')

    def test_ac_wg_07_le_nom_arrive_par_stdin(self):
        with patch.object(backend.sys, 'stdin', SimpleNamespace(readline=lambda: '{"name": "maison"}\n')), \
                patch.object(backend, 'rename', return_value={'ok': True}) as rename:
            backend.main(['rename', TARGET])
        rename.assert_called_once_with(TARGET, {'name': 'maison'})

    def test_ac_wg_n5_un_nom_vide_trop_long_ou_avec_controle_est_refuse(self):
        for name in ('', '   ', 'x' * 129, 'a\nb', 'tab\tulation', 'nul\x00', None):
            error, command = self.rename(TARGET, name)
            self.assertIsInstance(error, ValueError, repr(name))
            command.assert_not_called()

    def test_ac_wg_n5_un_identifiant_invalide_ou_inconnu_est_refuse(self):
        for identifier, known in (('$(touch /tmp/x)', None), (TARGET, [])):
            error, command = self.rename(identifier, 'maison', known)
            self.assertIsInstance(error, ValueError)
            command.assert_not_called()


# --- AC-WG-08 / AC-WG-N6 : supprimer -------------------------------------------

class DeleteTests(unittest.TestCase):
    def delete(self, identifier, known):
        with patch.object(backend, 'profiles', return_value=known), \
                patch.object(backend, 'nmcli') as command:
            try:
                return backend.main(['delete', identifier]), command
            except ValueError as error:
                return error, command

    def test_ac_wg_08_supprime_par_l_uuid(self):
        result, command = self.delete(TARGET, [profile(TARGET, False)])
        self.assertEqual(result, {'ok': True, 'stopped': []})
        command.assert_called_once_with('connection', 'delete', 'uuid', TARGET)

    def test_ac_wg_08_un_tunnel_actif_supprime_est_une_coupure_voulue(self):
        result, _ = self.delete(TARGET, [profile(TARGET, True)])
        self.assertEqual(result['stopped'], [TARGET])

    def test_ac_wg_n6_un_identifiant_invalide_ou_inconnu_est_refuse(self):
        for identifier, known in (('$(touch /tmp/x)', [profile(TARGET, False)]), (TARGET, [])):
            error, command = self.delete(identifier, known)
            self.assertIsInstance(error, ValueError)
            command.assert_not_called()

    def test_ac_wg_n6_un_profil_d_un_autre_type_n_est_pas_supprime(self):
        # profiles() ne rend que des wireguard : un uuid ethernet y est inconnu.
        error, command = self.delete('55555555-5555-5555-5555-555555555555', [profile(TARGET, False)])
        self.assertIsInstance(error, ValueError)
        command.assert_not_called()


# --- AC-WG-05 / AC-WG-N2 : import ----------------------------------------------

class ConfigurationTests(unittest.TestCase):
    def test_ac_wg_05_le_profil_importe_n_a_pas_d_autoconnect(self):
        conn, identifier = backend.build_tunnel(config(), 'Test')
        setting = conn.get_setting_connection()
        self.assertFalse(setting.get_autoconnect())
        self.assertEqual(setting.get_interface_name(), 'wg-' + identifier[:8])
        self.assertEqual(conn.get_setting_ip4_config().get_num_addresses(), 1)
        self.assertEqual(conn.get_setting_ip6_config().get_num_addresses(), 1)
        self.assertTrue(conn.verify())

    def test_ac_wg_05_l_import_enregistre_sans_jamais_activer(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'maison.conf'
            path.write_text(config())
            with patch.object(backend, 'save_connection') as save, \
                    patch.object(backend, 'nmcli') as command:
                result = backend.add_tunnel({'path': str(path), 'name': 'maison'})
        save.assert_called_once()
        command.assert_not_called()
        self.assertEqual(set(result), {'ok', 'uuid'})

    def test_ac_wg_05_plusieurs_peers_sont_conserves(self):
        text = config() + f'\n[Peer]\nPublicKey = {key()}\nAllowedIPs = 10.1.0.0/16\n'
        _, peers = backend.parse_config(text)
        self.assertEqual(len(peers), 2)

    def test_ac_wg_n2_les_options_hors_liste_blanche_sont_refusees_sans_echo(self):
        for line in ('PostUp = secret-command', 'PreDown = secret-command', 'Table = secret-command',
                     'SaveConfig = secret-command', 'FwMark = secret-command'):
            with self.assertRaises(ValueError, msg=line) as caught:
                backend.parse_config(config(extra_interface=line + '\n'))
            self.assertNotIn('secret-command', str(caught.exception))

    def test_ac_wg_n2_une_cle_de_mauvaise_longueur_est_refusee(self):
        short = base64.b64encode(os.urandom(16)).decode()
        with self.assertRaises(ValueError):
            backend.parse_config(f'[Interface]\nPrivateKey = {short}\n[Peer]\nPublicKey = {key()}\nAllowedIPs = ::/0\n')
        with self.assertRaises(ValueError):
            backend.parse_config(f'[Interface]\nPrivateKey = {key()}\n[Peer]\nPublicKey = {short}\nAllowedIPs = ::/0\n')

    def test_ac_wg_n2_un_peer_sans_allowedips_est_refuse(self):
        with self.assertRaises(ValueError):
            backend.parse_config(f'[Interface]\nPrivateKey = {key()}\n[Peer]\nPublicKey = {key()}\n')

    def test_ac_wg_n2_un_nom_vide_ou_trop_long_est_refuse(self):
        for name in ('', '   ', 'x' * 129):
            with self.assertRaises(ValueError):
                backend.build_tunnel(config(), name)

    def test_ac_wg_n2_une_configuration_trop_grosse_est_refusee(self):
        with self.assertRaises(ValueError):
            backend.parse_config(config() + '#' * backend.CONFIG_LIMIT)


class FileBoundaryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def test_ac_wg_n2_lien_symbolique_dossier_et_fifo_refuses(self):
        target = self.root / 'vrai.conf'
        target.write_text(config())
        link = self.root / 'lien.conf'
        link.symlink_to(target)
        with self.assertRaises(OSError):
            backend.read_config_file(link)
        with self.assertRaises(ValueError):
            backend.read_config_file(self.root)
        fifo = self.root / 'fifo.conf'
        os.mkfifo(fifo)
        with self.assertRaises(ValueError):
            backend.read_config_file(fifo)

    def test_ac_wg_n2_un_dossier_parent_symbolique_est_refuse(self):
        real = self.root / 'reel'
        real.mkdir()
        (real / 'a.conf').write_text(config())
        (self.root / 'raccourci').symlink_to(real, target_is_directory=True)
        with self.assertRaises(OSError):
            backend.read_config_file(self.root / 'raccourci' / 'a.conf')

    def test_ac_wg_n2_la_lecture_reste_sur_le_fichier_ouvert(self):
        path = self.root / 'a.conf'
        path.write_text('original')
        replacement = self.root / 'b.conf'
        replacement.write_text('remplace')
        real_fstat = os.fstat

        def swap(fd):
            info = real_fstat(fd)
            replacement.replace(path)
            return info

        with patch.object(backend.os, 'fstat', side_effect=swap):
            self.assertEqual(backend.read_config_file(path), 'original')

    def test_ac_wg_n2_taille_bornee_meme_si_le_fichier_grossit_apres_fstat(self):
        path = self.root / 'a.conf'
        path.write_bytes(b'x' * backend.CONFIG_LIMIT)
        self.assertEqual(len(backend.read_config_file(path)), backend.CONFIG_LIMIT)
        path.write_bytes(b'x' * (backend.CONFIG_LIMIT + 100))
        with self.assertRaises(ValueError):
            backend.read_config_file(path)
        real_read = os.read
        with patch.object(backend.os, 'fstat', return_value=SimpleNamespace(st_mode=stat.S_IFREG, st_size=0)), \
                patch.object(backend.os, 'read', wraps=real_read) as read:
            with self.assertRaises(ValueError):
                backend.read_config_file(path)
        self.assertEqual(sum(c.args[1] for c in read.call_args_list), backend.CONFIG_LIMIT + 1)

    def test_ac_wg_n2_un_encodage_invalide_ne_cite_pas_le_contenu(self):
        path = self.root / 'a.conf'
        path.write_bytes(b'secret-value\xff')
        with self.assertRaises(ValueError) as caught:
            backend.read_config_file(path)
        self.assertNotIn('secret-value', str(caught.exception))


if __name__ == '__main__':
    unittest.main()
