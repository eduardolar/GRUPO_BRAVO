"""Tests for 2FA recovery code utilities in routes/auth.py."""
import hashlib
from routes.auth import _generar_codigos_recuperacion, _buscar_codigo_recuperacion


class TestGenerarCodigosRecuperacion:
    def test_genera_ocho_codigos_por_defecto(self):
        codigos, hashes = _generar_codigos_recuperacion()
        assert len(codigos) == 8
        assert len(hashes) == 8

    def test_cantidad_personalizada(self):
        codigos, hashes = _generar_codigos_recuperacion(4)
        assert len(codigos) == 4
        assert len(hashes) == 4

    def test_formato_codigo_con_guion(self):
        HEX_UPPER = set("0123456789ABCDEF")
        codigos, _ = _generar_codigos_recuperacion()
        for codigo in codigos:
            partes = codigo.split("-")
            assert len(partes) == 2, f"Código sin guión: {codigo}"
            assert len(partes[0]) == 8
            assert len(partes[1]) == 8
            assert all(c in HEX_UPPER for c in partes[0]), f"Parte no es hex upper: {partes[0]}"
            assert all(c in HEX_UPPER for c in partes[1]), f"Parte no es hex upper: {partes[1]}"

    def test_codigos_unicos(self):
        codigos, _ = _generar_codigos_recuperacion(8)
        assert len(set(codigos)) == 8

    def test_hashes_son_sha256(self):
        _, hashes = _generar_codigos_recuperacion()
        for h in hashes:
            assert len(h) == 64, "SHA-256 debe tener 64 hex chars"

    def test_hash_corresponde_al_codigo(self):
        codigos, hashes = _generar_codigos_recuperacion()
        for codigo, h in zip(codigos, hashes):
            raw = codigo.replace("-", "").lower()
            expected = hashlib.sha256(raw.encode()).hexdigest()
            assert h == expected


class TestBuscarCodigoRecuperacion:
    def setup_method(self):
        self.codigos, self.hashes = _generar_codigos_recuperacion(8)

    def test_encuentra_codigo_exacto(self):
        codigo = self.codigos[0]
        resultado = _buscar_codigo_recuperacion(codigo, self.hashes)
        assert resultado is not None

    def test_acepta_codigo_sin_guion(self):
        codigo_sin_guion = self.codigos[0].replace("-", "")
        resultado = _buscar_codigo_recuperacion(codigo_sin_guion, self.hashes)
        assert resultado is not None

    def test_acepta_codigo_minusculas(self):
        codigo_lower = self.codigos[0].lower()
        resultado = _buscar_codigo_recuperacion(codigo_lower, self.hashes)
        assert resultado is not None

    def test_acepta_codigo_mixto(self):
        raw = self.codigos[0].replace("-", "")
        mixto = raw[:4].lower() + raw[4:].upper()
        resultado = _buscar_codigo_recuperacion(mixto, self.hashes)
        assert resultado is not None

    def test_codigo_incorrecto_devuelve_none(self):
        resultado = _buscar_codigo_recuperacion("00000000-00000000", self.hashes)
        assert resultado is None

    def test_devuelve_el_hash_correcto(self):
        codigo = self.codigos[3]
        h = _buscar_codigo_recuperacion(codigo, self.hashes)
        assert h == self.hashes[3]

    def test_lista_vacia_devuelve_none(self):
        resultado = _buscar_codigo_recuperacion(self.codigos[0], [])
        assert resultado is None
