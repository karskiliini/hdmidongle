import importlib.util
import os
import sys
from pathlib import Path
from unittest.mock import MagicMock
import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'receiver'))
spec = importlib.util.spec_from_file_location('dongle_config', os.environ.get('SECURITY_TEST_BASELINE', str(ROOT / 'receiver/config-server.py')))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
TOKEN = 'test-only-operator-token-with-at-least-32-characters'


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setenv('DONGLE_ADMIN_TOKEN', TOKEN)
    config = {'dongle_name': 'Test', 'wifi_ssid': 'Test WiFi', 'wifi_password': 'never-disclose-this', 'wifi_country': 'FI'}
    monkeypatch.setattr(module, 'load_config', lambda: config.copy())
    monkeypatch.setattr(module, 'get_system_info', lambda: {})
    monkeypatch.setattr(module, 'save_config', MagicMock())
    monkeypatch.setattr(module, 'apply_dongle_name', MagicMock())
    monkeypatch.setattr(module, 'apply_wifi', MagicMock(return_value=(True, 'fake')))
    monkeypatch.setattr(module.subprocess, 'Popen', MagicMock())
    return module.app.test_client()


def test_unauthorized_cannot_read_wifi_or_reboot(client, monkeypatch):
    assert client.get('/api/status').status_code == 401
    assert client.post('/api/reboot').status_code == 401
    module.subprocess.Popen.assert_not_called()
    monkeypatch.delenv('DONGLE_ADMIN_TOKEN')
    assert client.post('/api/reboot').status_code == 503


def test_authenticated_status_never_discloses_wifi_password(client):
    response = client.get('/api/status', headers={'Authorization': f'Bearer {TOKEN}'})
    assert response.status_code == 200
    assert response.json['config']['wifi_password'] == ''


def test_origin_and_config_injection_rejected(client):
    auth = {'Authorization': f'Bearer {TOKEN}'}
    assert client.post('/api/reboot', headers={**auth, 'Origin': 'https://attacker.invalid'}).status_code == 403
    for payload in [{'dongle_name': 'Name\ninject directive'}, {'mode': []}, ['not-an-object'], {'wifi_country': 'FI\nUS'}]:
        assert client.post('/api/config', json=payload, headers=auth).status_code == 400
    module.apply_dongle_name.assert_not_called()
    module.save_config.assert_not_called()


def test_authorized_command_and_password_preservation(client):
    auth = {'Authorization': f'Bearer {TOKEN}'}
    assert client.post('/api/restart', headers=auth).status_code == 200
    module.subprocess.Popen.assert_called_once_with(['systemctl', 'restart', 'dongle'])
    response = client.post('/api/config', json={'wifi_ssid': 'Test WiFi', 'wifi_password': ''}, headers=auth)
    assert response.status_code == 200
    module.apply_wifi.assert_called_once_with('Test WiFi', 'never-disclose-this', 'FI')
    assert response.json['config']['wifi_password'] == ''
