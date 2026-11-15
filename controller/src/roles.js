// Roles del contrato (docs/protocol.md). La clave es también la ruta: /controller/<rol>.
// Colores y nombres iguales que en el juego (game/Scripts/main_ui.gd: ROLE_COLORS, ROLE_LABELS):
// los cascos de los astronautas son de estos colores.
export const ROLES = {
  engineer: {
    name: 'Engineer',
    subtitle: 'Machines and power',
    code: 'ENG',
    color: '#ffd933',
    pale: '#fff6c9',
    dark: '#6b5600',
  },
  biologist: {
    name: 'Biologist',
    subtitle: 'Plants and life',
    code: 'BIO',
    color: '#66e680',
    pale: '#dcf9e2',
    dark: '#1a6a2b',
  },
  doctor: {
    name: 'Doctor',
    subtitle: 'Health and care',
    code: 'MED',
    color: '#ff6666',
    pale: '#ffe1e1',
    dark: '#7d2222',
  },
  generalist: {
    name: 'Commander',
    subtitle: 'Leads the crew',
    code: 'CMD',
    color: '#ffffff',
    pale: '#eef3ff',
    dark: '#1a2030',
  },
}

export const ROLE_IDS = ['engineer', 'biologist', 'doctor']

/** Variables CSS del color de un rol. */
export const roleStyle = (role) =>
  role ? { '--role-color': role.color, '--role-pale': role.pale, '--role-dark': role.dark } : {}
