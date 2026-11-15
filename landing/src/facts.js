// Datos reales de los eventos del juego (game/Data/events.json). La portada enseña uno al azar.
export const FACTS = [
  'In 2009, the Spirit rover got stuck in soft sand. NASA worked for months to free it.',
  'NASA’s InSight lander heard more than 1,300 Marsquakes using a sensor called SEIS.',
  'A machine called MOXIE rode on the Perseverance rover. It made oxygen from the air of Mars!',
  'The Opportunity rover kept working for years because wind cleaned its solar panels.',
  'NASA’s Curiosity rover found clay in Gale Crater. Clay forms when there is water.',
  'NASA’s DONKI system tracks solar flares and sun storms almost live.',
]

export const randomFact = () => FACTS[Math.floor(Math.random() * FACTS.length)]
