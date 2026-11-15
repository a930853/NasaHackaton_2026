"""Simulador de equilibrio: réplica en Python de las reglas de GameState / EventManager / TurnManager
(modo solo, sin alerta solar ni ayuda de la Tierra). Lee las cifras de game/Data/events.json.

    python tools/balance_sim.py [partidas]      # compara la configuración anterior con la actual

Las constantes de `Cfg` repiten las de game/Scripts/game_state.gd: si se cambian allí, hay que cambiarlas aquí.
Dos tipos de jugador: ATENTO (mira costes y objetivos y protege la barra más baja) y AL AZAR. Las personas
reales están entre los dos. Se comprobó que el juego real (Godot) reparte las derrotas igual que este
simulador cuando juega al azar. Documentación: docs/juego/diseno.md (apartado «Equilibrio»).
"""
import copy, json, random, sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "game" / "Data" / "events.json"
BASE = {e['id']: e for e in json.load(open(ROOT, encoding='utf-8'))['events']}
ROLES = ["engineer", "biologist", "doctor", "generalist"]
STATS = ["health", "oxygen", "energy", "integrity"]


class Cfg:
    def __init__(self, **kw):
        self.max_sols = 20
        self.start = 80
        self.o2_loss = 4              # PASSIVE_OXYGEN_LOSS
        self.energy_gain = 7          # PASSIVE_ENERGY_GAIN
        self.objective_priority = 0.7
        self.moxie_weight = 2.0       # "weight" de los eventos MOXIE en events.json
        self.cost_mult = {"health": 1.0, "oxygen": 1.0, "energy": 1.0, "integrity": 1.0}
        self.seismic_deadline = 13
        self.i_loss = 3               # PASSIVE_INTEGRITY_LOSS
        self.h_loss = 6               # PASSIVE_HEALTH_LOSS
        self.h_start = 4              # HEALTH_LOSS_FROM_SOL
        self.i_start = 1
        self.e_late_gain = 6          # PASSIVE_ENERGY_GAIN_DUSTY
        self.e_late_start = 8         # DUSTY_PANELS_FROM_SOL
        self.__dict__.update(kw)


def scaled_events(cfg):
    """Eventos con los costes (efectos negativos) multiplicados por stat."""
    events = copy.deepcopy(BASE)

    def scale(fx):
        for s in list(fx):
            if fx[s] < 0:
                fx[s] = round(fx[s] * cfg.cost_mult[s])

    def walk(o):
        if isinstance(o, dict):
            if 'effects' in o and isinstance(o['effects'], dict):
                scale(o['effects'])
            for k in ('on_fail', 'start_condition', 'on_start', 'on_end'):
                if k in o:
                    walk(o[k])
            for k in ('delayed', 'chance'):
                for x in o.get(k, []):
                    walk(x)
            for k in ('daily',):
                if k in o:
                    scale(o[k])
            for step in o.get('sequence', []):
                scale(step)
    for e in events.values():
        walk(e.get('on_start', {}))
        for o in e['options']:
            walk(o)
    return events


class Game:
    def __init__(self, cfg, policy, rng):
        self.cfg, self.policy, self.rng = cfg, policy, rng
        self.events = scaled_events(cfg)
        self.s = {k: cfg.start for k in STATS}
        self.sol = 1
        self.p = dict(harvests_completed=0, sensors_fabricated=False, sensors_placed=0, moxie_progress=0,
                      rover_rescued=False, quake_happened=False, e2_pending=False, seismic_alert_active=False)
        self.health_ok = True
        self.away = {}
        self.conds = []
        self.delayed = []
        self.seen = {}
        self.sched = []
        self.paused = []
        self.alert_new = False
        self.empty_days = 0
        self.moxie_sol = None

    # ---- recursos
    def mod(self, st, d):
        self.s[st] = max(0, min(100, self.s[st] + d))
        if st == "health" and self.s["health"] <= 50:
            self.health_ok = False

    def outcome(self, o):
        for st, d in o.get('effects', {}).items():
            self.mod(st, d)
        for k, v in o.get('add', {}).items():
            self.p[k] = max(0, self.p[k] + v)
        for k, v in o.get('set', {}).items():
            self.p[k] = v
        for r in o.get('chance', []):
            if self.rng.random() <= r['probability']:
                for st, d in r.get('effects', {}).items():
                    self.mod(st, d)
        for d in o.get('delayed', []):
            self.delayed.append((self.sol + d.get('after_sols', 1), d))
        if 'start_condition' in o:
            c = copy.deepcopy(o['start_condition'])
            c['sols_left'] = c.get('sols', 1)
            c['step'] = 0
            self.conds = [x for x in self.conds if x['id'] != c['id']] + [c]
        if 'away_all' in o:
            self.send_all(o['away_all'], True)
        if self.p['sensors_placed'] >= 3 and not self.p['seismic_alert_active'] and self.sol < self.cfg.seismic_deadline:
            self.p['seismic_alert_active'] = True
            self.alert_new = True
        elif self.p['sensors_placed'] < 3 and self.p['seismic_alert_active']:
            self.p['seismic_alert_active'] = False
        if self.p['moxie_progress'] >= 100 and self.moxie_sol is None:
            self.moxie_sol = self.sol

    def failure(self, op):
        costs = {s: d for s, d in op.get('effects', {}).items() if d < 0}
        self.outcome({'effects': costs})
        self.outcome(op.get('on_fail', {}))

    # ---- tripulación
    def send(self, role, n, today=False):
        if n > 0:
            self.away[role] = self.sol + n + (0 if today else 1)

    def send_all(self, n, today=False):
        for r in ROLES:
            self.send(r, n, today)

    def block(self, op):
        role = op.get('role')
        if role is not None:
            return role in self.away
        return op.get('away_sols', 0) > 0 and len(self.away) > 0

    # ---- condiciones
    def cond_met(self, c):
        if not c:
            return True
        if 'min_sol' in c and self.sol < c['min_sol']: return False
        if 'max_sol' in c and self.sol > c['max_sol']: return False
        for k, v in c.get('state', {}).items():
            if self.p[k] != v: return False
        for k, v in c.get('state_gt', {}).items():
            if self.p[k] <= v: return False
        for k, v in c.get('state_lt', {}).items():
            if self.p[k] >= v: return False
        if 'any_of' in c and not any(self.cond_met(x) for x in c['any_of']):
            return False
        return True

    def available(self, e):
        if e['id'] in self.seen and self.sol - self.seen[e['id']] < e.get('cooldown_sols', 999):
            return False
        return self.cond_met(e.get('conditions'))

    def valid(self, kind):
        return [e for e in self.events.values() if e['kind'] == kind and not e.get('scheduled_only') and self.available(e)]

    def pick(self):
        auto = self.valid('auto')
        if auto:
            return auto[0]
        for i, (due, eid) in enumerate(self.sched):
            if due <= self.sol:
                self.sched.pop(i)
                ev = self.events[eid]
                return ev if self.cond_met(ev.get('conditions')) else None
        objs, rnd = self.valid('objective'), self.valid('random')
        if objs and (not rnd or self.rng.random() < self.cfg.objective_priority):
            w = [self.cfg.moxie_weight if e['id'].startswith('moxie') else 1.0 for e in objs]
            return self.rng.choices(objs, weights=w)[0]
        if rnd:
            return self.rng.choice(rnd)
        fill = self.valid('filler')
        return self.rng.choice(fill) if fill else None

    # ---- turnos
    def defeat(self):
        for st in STATS:
            if self.s[st] <= 0:
                return st
        return None

    def run(self):
        first = True
        while True:
            if first:
                first = False
            else:
                self.sol += 1
                for r in [r for r, back in self.away.items() if self.sol >= back]:
                    del self.away[r]
                if self.p['moxie_progress'] < 100:
                    self.mod('oxygen', -self.cfg.o2_loss)
                late = self.cfg.e_late_gain is not None and self.sol >= self.cfg.e_late_start
                self.mod('energy', self.cfg.e_late_gain if late else self.cfg.energy_gain)
                if self.sol >= self.cfg.h_start:
                    self.mod('health', -self.cfg.h_loss)
                if self.sol >= self.cfg.i_start:
                    self.mod('integrity', -self.cfg.i_loss)
                rem = []
                for c in self.conds:
                    daily = c['sequence'][c['step']] if 'sequence' in c and c['step'] < len(c['sequence']) else c.get('daily', {}) if 'sequence' not in c else {}
                    if daily:
                        self.outcome({'effects': daily})
                    c['step'] += 1
                    c['sols_left'] -= 1
                    if c['sols_left'] > 0:
                        rem.append(c)
                    elif 'on_end' in c:
                        self.outcome(c['on_end'])
                self.conds = rem
                due = [o for d, o in self.delayed if d <= self.sol]
                self.delayed = [(d, o) for d, o in self.delayed if d > self.sol]
                for o in due:
                    self.outcome(o)
                if self.alert_new:
                    self.alert_new = False
                    self.sched.append((self.sol + self.rng.randint(1, 2), 'quake-warned'))
            if self.defeat():
                return False, self.defeat()
            if len(self.away) == 4:
                self.empty_days += 1
            else:
                ev, fresh = None, True
                for i, (ret, e) in enumerate(self.paused):
                    if ret <= self.sol:
                        ev, fresh = self.paused.pop(i)[1], False
                        break
                if ev is None:
                    ev = self.pick()
                if ev is not None:
                    self.present(ev, fresh)
                    if self.defeat() and self.sol <= self.cfg.max_sols:
                        pass
            d = self.defeat()
            if d:
                return False, d
            if self.sol >= self.cfg.max_sols:
                return True, None

    def present(self, ev, fresh):
        if fresh:
            self.seen[ev['id']] = self.sol
            if 'on_start' in ev:
                self.outcome(ev['on_start'])
                if self.defeat():
                    return
        options = [o for o in ev['options'] if not self.block(o)]
        if not options:
            back = min(self.away.values()) if self.away else self.sol + 1
            self.paused.append((back, self.events[ev['id']]))
            return
        op = self.policy(self, ev, options)
        self.apply(ev, op)

    def apply(self, ev, op):
        ok = self.rng.random() <= op.get('success_chance', 1.0)
        if ok:
            self.outcome(op)
            if 'schedule_event' in op:
                sc = op['schedule_event']
                self.sched.append((self.sol + self.rng.randint(sc.get('min_sols', 1), sc.get('max_sols', 1)), sc['id']))
        else:
            self.failure(op)
            if ev.get('retry_on_fail'):
                self.seen.pop(ev['id'], None)
        n = op.get('away_sols', 0)
        if n > 0:
            if op.get('role') is not None:
                self.send(op['role'], n)
            else:
                self.send_all(n)
        if self.alert_new:
            self.alert_new = False
            self.sched.append((self.sol + self.rng.randint(1, 2), 'quake-warned'))

    def objectives(self):
        return sum([self.health_ok, self.p['harvests_completed'] >= 3, self.p['rover_rescued'],
                    self.p['sensors_placed'] >= 3, self.p['moxie_progress'] >= 100])


# ---------------------------------------------------------------- políticas

def random_policy(g, ev, options):
    return g.rng.choice(options)


def smart_policy(g, ev, options):
    """Jugador atento: mira el valor esperado de cada opción y protege la barra más baja,
    con un empujón a los objetivos y sin salir fuera con la base en las últimas."""
    def urgency(v):
        return 1.0 / (max(v, 1) + 8.0)

    def score(op):
        p = op.get('success_chance', 1.0)
        fx = op.get('effects', {})
        after = dict(g.s)
        total = 0.0
        for st, d in fx.items():
            gain = d * (1.0 if d < 0 else p)
            after[st] = max(0, min(100, after[st] + gain))
        for st in STATS:
            total -= (urgency(after[st]) - urgency(g.s[st])) * -1 * 0  # placeholder (mantiene la forma)
        total = sum(-urgency(after[st]) for st in STATS)
        # diferidos y condiciones multi-Sol
        for d in op.get('delayed', []):
            for st, v in d.get('effects', {}).items():
                total += p * v * urgency(after[st]) * 0.6
        sc = op.get('start_condition')
        if sc:
            daily = sc.get('daily')
            if daily:
                for st, v in daily.items():
                    total += v * sc.get('sols', 1) * urgency(after[st]) * 0.6
            for step in sc.get('sequence', []):
                for st, v in step.items():
                    total += v * urgency(after[st]) * 0.6
        # objetivos
        prog = 0.0
        for k, v in op.get('set', {}).items():
            if k == 'moxie_progress':
                prog += 0.012 * max(0, v - g.p['moxie_progress'])
            elif k in ('rover_rescued', 'sensors_fabricated') and v is True:
                prog += 0.35
            elif k == 'sensors_placed':
                prog += 0.2 * max(0, v - g.p['sensors_placed'])
        for k, v in op.get('add', {}).items():
            prog += 0.3 * v if k == 'harvests_completed' else (0.25 * v if k == 'sensors_placed' else 0)
        total += prog * p
        # ocupación
        n = op.get('away_sols', 0)
        if n:
            total -= 0.015 * n * (4 if op.get('role') is None else 1)
        # cuenta atrás: usar la opción por defecto del evento si empata
        return total

    return max(options, key=score)


def run(cfg, policy, n, seed=1):
    rng = random.Random(seed)
    res = Counter()
    objs = 0
    moxie = []
    oxy_empty = 0
    finals = {k: 0 for k in STATS}
    wins = 0
    empty_days = 0
    for _ in range(n):
        g = Game(cfg, policy, rng)
        ok, why = g.run()
        res['win' if ok else why] += 1
        objs += g.objectives()
        empty_days += g.empty_days
        if g.moxie_sol:
            moxie.append(g.moxie_sol)
        if ok:
            for k in STATS:
                finals[k] += g.s[k]
    return dict(n=n, win=res['win'] / n, health=res['health'] / n, oxygen=res['oxygen'] / n, energy=res['energy'] / n,
                integrity=res['integrity'] / n, objs=objs / n, moxie_done=len(moxie) / n,
                moxie_sol=(sum(moxie) / len(moxie) if moxie else 0), empty=empty_days / n,
                finals={k: round(v / max(1, res['win']), 1) for k, v in finals.items()})


def row(name, r):
    print(f"{name:<46} win {r['win']*100:5.1f}% | pierde por  O2 {r['oxygen']*100:4.1f}%  E {r['energy']*100:4.1f}%  "
          f"H {r['health']*100:4.1f}%  I {r['integrity']*100:4.1f}% | MOXIE {r['moxie_done']*100:3.0f}% (Sol {r['moxie_sol']:.1f}) | obj {r['objs']:.2f}")


if __name__ == '__main__':
    N = int(sys.argv[1]) if len(sys.argv) > 1 else 3000
    before = Cfg(o2_loss=5, energy_gain=10, e_late_gain=None, moxie_weight=1.0, i_loss=0, h_loss=0)
    rows = [("Antes (O2 -5, energía +10, sin desgaste)", before), ("Ahora (reglas actuales)", Cfg())]
    for pname, pol in (("ATENTO", smart_policy), ("AL AZAR", random_policy)):
        print("\n=== Jugador %s (%d partidas por fila) ===" % (pname, N))
        for name, cfg in rows:
            row(name, run(cfg, pol, N))
