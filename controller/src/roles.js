// Roles del contrato (docs/protocol.md). La clave es también la ruta: /controller/<rol>.
export const ROLES = {
  engineer: {
    name: 'Ingeniero',
    subtitle: 'Sistemas y tecnología',
    code: 'ENG',
    color: '#f5b940',
    pale: '#fff3ce',
    dark: '#7b5100',
  },
  biologist: {
    name: 'Biólogo',
    subtitle: 'Vida y ecosistemas',
    code: 'BIO',
    color: '#57c98b',
    pale: '#dcf8e9',
    dark: '#17603d',
  },
  doctor: {
    name: 'Médico',
    subtitle: 'Salud y bienestar',
    code: 'MED',
    color: '#f17474',
    pale: '#ffe1e1',
    dark: '#812d2d',
  },
  generalist: {
    name: 'Polivalente',
    subtitle: 'Misión y coordinación',
    code: 'OPS',
    color: '#ffffff',
    pale: '#dfedff',
    dark: '#235185',
  },
}

export const ROLE_IDS = Object.keys(ROLES)

/** Variables CSS del color de un rol. */
export const roleStyle = (role) =>
  role ? { '--role-color': role.color, '--role-pale': role.pale, '--role-dark': role.dark } : {}
