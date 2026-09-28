import socket
import unittest
from unittest.mock import MagicMock, patch
from test_dock_minimize import dm

class HelperLimitsTest(unittest.TestCase):
    def test_socket_timeout_closes_connection(self):
        connection = MagicMock()
        connection.__enter__.return_value = connection
        connection.recv.side_effect = socket.timeout()
        with patch.object(dm.socket, 'socket', return_value=connection):
            self.assertEqual(dm.hypr_cmd('/test.sock', 'j/clients'), '')
        connection.__exit__.assert_called_once()
        connection.settimeout.assert_any_call(2.0)

    def test_oversized_response_is_discarded(self):
        connection = MagicMock()
        connection.__enter__.return_value = connection
        connection.recv.return_value = b'x' * (8 * 1024 * 1024 + 1)
        with patch.object(dm.socket, 'socket', return_value=connection):
            self.assertEqual(dm.hypr_cmd('/test.sock', 'j/clients'), '')
        connection.__exit__.assert_called_once()

    def test_normal_response_is_collected(self):
        connection = MagicMock()
        connection.__enter__.return_value = connection
        connection.recv.side_effect = [b'[', b']', b'']
        with patch.object(dm.socket, 'socket', return_value=connection):
            self.assertEqual(dm.hypr_cmd('/test.sock', 'j/clients'), '[]')

    def test_lua_value_remains_one_string(self):
        self.assertEqual(dm.lua_string('a"; os.execute("bad") --\n\\'), '"a\\"; os.execute(\\"bad\\") --\\010\\\\"')
        self.assertEqual(dm.lua_string('Café'), '"Café"')
