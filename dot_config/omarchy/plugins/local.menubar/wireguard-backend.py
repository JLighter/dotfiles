#!/usr/bin/env python3
# Helper du widget WireGuard de la menubar : tout ce qui parle a NetworkManager
# ou touche une cle passe par ici, jamais par la QML. Une sous-commande par
# appel, une ligne JSON en sortie, un code de retour non nul en cas d'erreur.
#
#   status          tunnels WireGuard, etat, compteurs de l'interface
#   up <uuid>       active, apres avoir coupe les autres full tunnels actifs
#   down <uuid>     desactive
#   rename <uuid>   renomme ; {"name"} sur stdin
#   delete <uuid>   supprime le profil (irreversible)
#   add             importe un .conf ; {"path", "name"} sur stdin
#
# Les cles privees n'entrent que par stdin (le chemin du .conf) ou par le fichier
# lui-meme, et ne ressortent jamais : ni en argv, ni sur stdout, ni dans un
# message d'erreur.
#
# libnm n'est charge que par `up` et `add` : `status` tourne toutes les 2 s et
# se contente de nmcli et de sysfs.
#
# Adapte de omarchy-wireguard, https://github.com/VirtualDataPro/omarchy-wireguard
#
#   MIT License
#
#   Copyright (c) 2026 VirtualDataPro
#
#   Permission is hereby granted, free of charge, to any person obtaining a copy
#   of this software and associated documentation files (the "Software"), to deal
#   in the Software without restriction, including without limitation the rights
#   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#   copies of the Software, and to permit persons to whom the Software is
#   furnished to do so, subject to the following conditions:
#
#   The above copyright notice and this permission notice shall be included in all
#   copies or substantial portions of the Software.
#
#   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#   SOFTWARE.

import base64
import configparser
from contextlib import contextmanager
import ipaddress
import json
import os
from pathlib import Path
import re
import socket
import stat
import subprocess
import sys
import time
import uuid

CONFIG_LIMIT = 262144


class ActionError(RuntimeError):
    """Echec d'une action apres que d'autres tunnels ont deja ete coupes.

    La QML a besoin de `stopped` pour ne pas prendre ces coupures voulues pour
    des pannes.
    """

    def __init__(self, message, stopped):
        super().__init__(message)
        self.stopped = list(stopped)


# --- NetworkManager -----------------------------------------------------------

# `nmcli -e yes` echappe `:` et `\` dans les valeurs : un simple split(':')
# couperait le nom d'un tunnel comme « Travail: VPN ».
def fields(line):
    result, value, escaped = [], '', False
    for char in line:
        if escaped:
            value += char
            escaped = False
        elif char == '\\':
            escaped = True
        elif char == ':':
            result.append(value)
            value = ''
        else:
            value += char
    if escaped:
        value += '\\'
    return result + [value]


def nmcli(*args):
    result = subprocess.run(['nmcli', '--wait', '30', *args], capture_output=True,
                            text=True, timeout=35, env={**os.environ, 'LC_ALL': 'C'})
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or 'NetworkManager a refuse la requete')
    return result.stdout


# Le nom vient de nmcli : on le borne avant d'en faire un chemin sous /sys.
def counters(device):
    if not re.fullmatch(r'[A-Za-z0-9_.-]{1,15}', device or '') or device in ('.', '..'):
        return None
    try:
        root = Path('/sys/class/net') / device / 'statistics'
        return {'rx': int((root / 'rx_bytes').read_text()),
                'tx': int((root / 'tx_bytes').read_text())}
    except (OSError, ValueError):
        return None


def profiles():
    output = nmcli('-t', '-e', 'yes', '-f', 'UUID,TYPE,NAME,STATE,DEVICE', 'connection', 'show')
    rows = []
    for line in output.splitlines():
        row = fields(line)
        if len(row) != 5 or row[1] != 'wireguard':
            continue
        # Un profil inactif sort avec STATE et DEVICE vides.
        active = row[3] == 'activated'
        rows.append(dict(uuid=row[0], name=row[2], state=row[3] or 'deactivated', active=active,
                         device=row[4], counters=counters(row[4]) if active else None))
    return sorted(rows, key=lambda row: row['name'].casefold())


def libraries():
    import gi
    gi.require_version('NM', '1.0')
    from gi.repository import NM, GLib
    return NM, GLib


def require_tunnel(identifier):
    identifier = str(uuid.UUID(identifier))
    known = profiles()
    if not any(p['uuid'] == identifier for p in known):
        raise ValueError('Tunnel WireGuard inconnu de NetworkManager')
    return identifier, known


# --- Un seul full tunnel a la fois --------------------------------------------

# Deux tunnels ne peuvent pas se disputer la route par defaut ; des split
# tunnels sur des sous-reseaux disjoints cohabitent sans se gener.
def covers_default_route(allowed_ips):
    for value in allowed_ips:
        try:
            if ipaddress.ip_network(value.strip(), strict=False).prefixlen == 0:
                return True
        except ValueError:
            continue
    return False


# Lit les AllowedIPs dans la configuration NetworkManager plutot que dans les
# routes du noyau : un full tunnel range sa route par defaut dans une table
# dediee, invisible a un `ip route show default`. Les AllowedIPs ne sont pas des
# secrets, libnm les donne sans demander les cles.
def full_tunnels(identifiers):
    NM, _ = libraries()
    client = NM.Client.new(None)
    result = set()
    for identifier in identifiers:
        conn = client.get_connection_by_uuid(identifier)
        setting = conn.get_setting(NM.SettingWireGuard) if conn else None
        if setting is None:
            continue
        allowed = []
        for i in range(setting.get_peers_len()):
            peer = setting.get_peer(i)
            allowed += [peer.get_allowed_ip(j, None) for j in range(peer.get_allowed_ips_len())]
        if covers_default_route([ip for ip in allowed if ip]):
            result.add(identifier)
    return result


def up(identifier):
    identifier, known = require_tunnel(identifier)
    others = [p['uuid'] for p in known if p['active'] and p['uuid'] != identifier]
    full = full_tunnels([identifier] + others) if others else set()

    # Pas de rollback si l'activation echoue ensuite : comme omarchy-vpn, on
    # prefere un etat lisible (tout coupe, erreur affichee) a une restauration
    # qui peut elle-meme echouer a moitie.
    stopped = []
    if identifier in full:
        for other in others:
            if other not in full:
                continue
            try:
                nmcli('connection', 'down', 'uuid', other)
            except (RuntimeError, subprocess.TimeoutExpired, OSError):
                raise ActionError('Impossible de couper le tunnel en place', stopped) from None
            stopped.append(other)

    try:
        nmcli('connection', 'up', 'uuid', identifier)
    except RuntimeError as error:
        raise ActionError(str(error), stopped) from None
    except (subprocess.TimeoutExpired, OSError):
        raise ActionError("L'activation n'a pas abouti", stopped) from None
    return {'ok': True, 'stopped': stopped}


def down(identifier):
    identifier, _ = require_tunnel(identifier)
    nmcli('connection', 'down', 'uuid', identifier)
    return {'ok': True}


# Le nom est valide avant de toucher NetworkManager ; seul `connection.id`
# change, les cles et les peers restent tels quels.
def rename(identifier, data):
    name = clean_name(data.get('name'))
    identifier, _ = require_tunnel(identifier)
    nmcli('connection', 'modify', 'uuid', identifier, 'connection.id', name)
    return {'ok': True}


# Irreversible : la cle privee part avec le profil. La confirmation se fait
# cote panneau. Un tunnel actif supprime tombe, et c'est voulu : il est rendu
# dans `stopped` pour ne pas declencher d'alerte de coupure.
def delete(identifier):
    identifier, known = require_tunnel(identifier)
    was_active = any(p['uuid'] == identifier and p['active'] for p in known)
    nmcli('connection', 'delete', 'uuid', identifier)
    return {'ok': True, 'stopped': [identifier] if was_active else []}


# --- Import d'un .conf --------------------------------------------------------

def split_values(value):
    return [v.strip() for v in value.split(',') if v.strip()]


def valid_key(value):
    try:
        return len(base64.b64decode(value, validate=True)) == 32
    except (ValueError, TypeError):
        return False


# Liste blanche stricte : ignorer en silence un PostUp ou un Table laisserait
# croire qu'il s'appliquera. Aucun message ne cite le contenu du fichier.
def parse_config(text):
    if len(text) > CONFIG_LIMIT:
        raise ValueError('Configuration trop volumineuse')
    count = 0
    lines = []
    for line in text.splitlines():
        if line.strip().lower() == '[peer]':
            count += 1
            line = f'[Peer{count}]'
        lines.append(line)
    parser = configparser.ConfigParser(interpolation=None, strict=True,
                                       inline_comment_prefixes=('#', ';'))
    try:
        parser.read_string('\n'.join(lines))
    except configparser.Error:
        raise ValueError('Syntaxe de configuration WireGuard invalide') from None
    if 'Interface' not in parser or not count:
        raise ValueError('Il faut une section [Interface] et au moins un [Peer]')
    interface_keys = {'privatekey', 'address', 'dns', 'mtu', 'listenport'}
    peer_keys = {'publickey', 'presharedkey', 'endpoint', 'allowedips', 'persistentkeepalive'}
    for section in parser.sections():
        if section == 'Interface':
            allowed = interface_keys
        elif re.fullmatch(r'Peer\d+', section):
            allowed = peer_keys
        else:
            allowed = None
        if allowed is None or set(parser[section]) - allowed:
            raise ValueError('Option non prise en charge : hooks (PostUp...), Table, '
                             'SaveConfig et FwMark ne sont pas importes')
    interface = dict(parser['Interface'])
    if not valid_key(interface.get('privatekey', '')):
        raise ValueError('Cle privee invalide')
    try:
        for address in split_values(interface.get('address', '')):
            ipaddress.ip_interface(address)
        for server in split_values(interface.get('dns', '')):
            ipaddress.ip_address(server)
    except ValueError:
        raise ValueError('Adresse ou DNS invalide') from None
    peers = [dict(parser[f'Peer{i}']) for i in range(1, count + 1)]
    for peer in peers:
        if not valid_key(peer.get('publickey', '')) or (
                'presharedkey' in peer and not valid_key(peer['presharedkey'])):
            raise ValueError('Cle de peer invalide')
        if not peer.get('allowedips'):
            raise ValueError('Chaque peer doit avoir des AllowedIPs')
        try:
            for address in split_values(peer['allowedips']):
                ipaddress.ip_network(address, strict=False)
        except ValueError:
            raise ValueError('AllowedIPs invalide') from None
    return interface, peers


def integer(value, minimum, maximum, label):
    try:
        result = int(value)
    except (ValueError, TypeError):
        raise ValueError(f'{label} doit etre un nombre') from None
    if not minimum <= result <= maximum:
        raise ValueError(f'{label} doit etre entre {minimum} et {maximum}')
    return result


def apply_ip(conn, addresses, dns):
    NM, _ = libraries()
    networks = [ipaddress.ip_interface(a) for a in split_values(addresses)]
    servers = [ipaddress.ip_address(a) for a in split_values(dns)]
    for version, cls, family in [(4, NM.SettingIP4Config, socket.AF_INET),
                                 (6, NM.SettingIP6Config, socket.AF_INET6)]:
        setting = cls.new()
        conn.add_setting(setting)
        ips = [a for a in networks if a.version == version]
        setting.set_property('method', 'manual' if ips else 'disabled')
        for address in ips:
            setting.add_address(NM.IPAddress.new(family, str(address.ip), address.network.prefixlen))
        for server in servers:
            if server.version == version:
                setting.add_dns(str(server))


# Un saut de ligne ou une tabulation dans un nom casserait la sortie
# `nmcli -t` et l'affichage du panneau.
def clean_name(name):
    name = str(name or '').strip()
    if not name or len(name) > 128:
        raise ValueError('Le nom du tunnel doit faire de 1 a 128 caracteres')
    if any(ord(char) < 32 or ord(char) == 127 for char in name):
        raise ValueError('Le nom ne doit pas contenir de caractere de controle')
    return name


# Le profil nait desactive : autoconnect coupe, et rien ici ne l'active.
def build_tunnel(text, name):
    NM, _ = libraries()
    interface, peers = parse_config(text)
    name = clean_name(name)
    identifier = str(uuid.uuid4())
    conn = NM.SimpleConnection.new()
    setting = NM.SettingConnection.new()
    for prop, value in [('id', name), ('uuid', identifier), ('type', 'wireguard'),
                        ('autoconnect', False), ('interface-name', 'wg-' + identifier[:8])]:
        setting.set_property(prop, value)
    conn.add_setting(setting)
    wg = NM.SettingWireGuard.new()
    wg.set_property('private-key', interface['privatekey'])
    wg.set_property('mtu', integer(interface.get('mtu', 0), 0, 65535, 'MTU'))
    wg.set_property('listen-port', integer(interface.get('listenport', 0), 0, 65535, 'ListenPort'))
    for item in peers:
        peer = NM.WireGuardPeer.new()
        peer.set_public_key(item['publickey'], False)
        if item.get('presharedkey'):
            peer.set_preshared_key(item['presharedkey'], False)
        if item.get('endpoint') and not peer.set_endpoint(item['endpoint'], False):
            raise ValueError('Endpoint invalide : host:port ou [IPv6]:port')
        for address in split_values(item['allowedips']):
            peer.append_allowed_ip(address, False)
        peer.set_persistent_keepalive(
            integer(item.get('persistentkeepalive', 0), 0, 65535, 'PersistentKeepalive'))
        wg.append_peer(peer)
    conn.add_setting(wg)
    apply_ip(conn, interface.get('address', ''), interface.get('dns', ''))
    conn.verify()
    return conn, identifier


# `add_connection_async(conn, True)` enregistre le profil sur disque sans
# l'activer, a la difference de `add_and_activate_connection`.
def save_connection(conn):
    NM, GLib = libraries()
    client = NM.Client.new(None)
    loop = GLib.MainLoop()
    outcome = []

    def finished(source, result, _):
        try:
            source.add_connection_finish(result)
            outcome.append(None)
        except GLib.Error:
            outcome.append("NetworkManager n'a pas pu enregistrer le tunnel")
        loop.quit()

    client.add_connection_async(conn, True, None, finished, None)
    loop.run()
    if outcome[0]:
        raise RuntimeError(outcome[0])


def add_tunnel(data):
    conn, identifier = build_tunnel(read_config_file(str(data.get('path', ''))), data.get('name'))
    save_connection(conn)
    return {'ok': True, 'uuid': identifier}


# Descend depuis / par descripteurs de dossier : aucun lien symbolique n'est
# suivi, pas meme dans un dossier parent.
@contextmanager
def open_directory(path):
    path = Path(os.path.abspath(path))
    flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC
    fd = os.open('/', flags)
    try:
        for part in path.parts[1:]:
            child = os.open(part, flags, dir_fd=fd)
            os.close(fd)
            fd = child
        yield fd
    finally:
        os.close(fd)


def read_config_file(filename):
    if not filename:
        raise ValueError('Aucun fichier choisi')
    path = Path(os.path.abspath(Path(filename).expanduser()))
    with open_directory(path.parent) as parent:
        # O_NONBLOCK : une FIFO ne doit pas bloquer l'ouverture.
        fd = os.open(path.name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_CLOEXEC,
                     dir_fd=parent)
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_size > CONFIG_LIMIT:
            raise ValueError('Choisis un fichier ordinaire de 256 Kio au plus')
        # Le fichier peut grossir apres fstat : la lecture elle-meme est bornee.
        content = bytearray()
        while len(content) <= CONFIG_LIMIT:
            chunk = os.read(fd, min(65536, CONFIG_LIMIT + 1 - len(content)))
            if not chunk:
                break
            content.extend(chunk)
        if len(content) > CONFIG_LIMIT:
            raise ValueError('Configuration trop volumineuse')
        try:
            return content.decode('utf-8')
        except UnicodeDecodeError:
            raise ValueError('La configuration doit etre du texte UTF-8') from None
    finally:
        os.close(fd)


# --- Point d'entree -----------------------------------------------------------

def main(args):
    if args == ['status']:
        return {'profiles': profiles(), 'time': time.monotonic()}
    if len(args) == 2 and args[0] == 'up':
        return up(args[1])
    if len(args) == 2 and args[0] == 'down':
        return down(args[1])
    if len(args) == 2 and args[0] == 'rename':
        return rename(args[1], json.loads(sys.stdin.readline()))
    if len(args) == 2 and args[0] == 'delete':
        return delete(args[1])
    if args == ['add']:
        return add_tunnel(json.loads(sys.stdin.readline()))
    raise ValueError('Action WireGuard inconnue')


# Seuls nos propres messages sortent : jamais un extrait du parseur, une charge
# D-Bus ou une cle.
def error_payload(error):
    if isinstance(error, (ValueError, RuntimeError)):
        message = str(error)
    else:
        message = 'Requete impossible : verifie la configuration et NetworkManager'
    return {'error': message, 'stopped': getattr(error, 'stopped', [])}


if __name__ == '__main__':
    try:
        print(json.dumps(main(sys.argv[1:])))
    except Exception as error:
        print(json.dumps(error_payload(error)))
        sys.exit(1)
