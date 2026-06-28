import {
  ArrowLeft,
  Camera,
  Check,
  ChevronLeft,
  ChevronRight,
  Dumbbell,
  Flame,
  Globe2,
  ListChecks,
  MapPin,
  Minus,
  Pencil,
  Plus,
  Save,
  Share2,
  Target,
  Trash2,
  Undo2,
  Users,
  UserRound,
  X,
} from 'lucide-react'
import { useEffect, useMemo, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
import type { PointerEvent, TransitionEvent } from 'react'
import './App.css'
import { exerciseCatalog } from './exerciseCatalog'

type ExerciseStatus = 'pending' | 'done' | 'skipped'
type Tab = 'train' | 'plan' | 'ranking' | 'partner' | 'profile'

type Exercise = {
  id: string
  day: string
  name: string
  targetSets: number
  sets: number
  completedSets: number
  skippedSets: number
  reps: number
  weight: number
  rest: number
  xp: number
  note: string
  status: ExerciseStatus
}

type Player = {
  xp: number
  streak: number
  focus: number
  hearts: number
}

type Profile = {
  photo: string
  photoX: number
  photoY: number
  sex: string
  age: string
  country: string
  city: string
  gym: string
}

type HistoryEntry = {
  id: string
  exerciseId: string
  exerciseName: string
  day: string
  status: Exclude<ExerciseStatus, 'pending'>
  sets: number
  reps: number
  weight: number
  volume: number
  xp: number
  completedAt: string
  isPr: boolean
  sessionId?: string
  workoutName?: string
  sessionStartedAt?: string
  sessionElapsedSeconds?: number
  setIndex?: number
  totalSetsInExercise?: number
  setDurationSeconds?: number
  restBeforeSeconds?: number
  exerciseRestSeconds?: number
}

type PersonalRecord = {
  exerciseName: string
  weight: number
  reps: number
  sets: number
  volume: number
  date: string
}

type Preferences = {
  units: 'kg' | 'lb'
  reduceMotion: boolean
  coaching: boolean
  sounds: boolean
}

type Snapshot = {
  exercises: Exercise[]
  player: Player
  lastAction: string
  history: HistoryEntry[]
  prs: Record<string, PersonalRecord>
  preferences: Preferences
  profile?: Profile
  savedWorkouts?: WorkoutTemplate[]
  hiddenWorkoutIds?: string[]
}

type WorkoutState = {
  schemaVersion: 3
  exercises: Exercise[]
  player: Player
  lastAction: string
  history: HistoryEntry[]
  prs: Record<string, PersonalRecord>
  preferences: Preferences
  profile: Profile
  savedWorkouts: WorkoutTemplate[]
  hiddenWorkoutIds: string[]
  undoStack: Snapshot[]
}

type NewExercise = {
  name: string
  sets: number
  reps: number
  weight: number
}

type DraftExercise = NewExercise & {
  id: string
}

type WorkoutTemplate = {
  name: string
  description: string
  block?: string
  workout?: string
  exercises?: Exercise[]
}

type WorkoutLibraryItem = WorkoutTemplate & {
  libraryId: string
  source: 'template' | 'saved'
  removable: boolean
}

type Celebration = {
  id: number
  type: 'done' | 'pr' | 'skipped'
  message: string
  value?: string
}

type SoundCue = Celebration['type'] | 'tap' | 'tick' | 'start' | 'finish' | 'set' | 'exercise'
type SessionStatus = 'ready' | 'active' | 'finished'
type MascotMood = 'ready' | 'active' | 'rest' | 'finished' | 'cheer' | 'miss' | 'pr'
type RankingScope = 'global' | 'country' | 'city' | 'zone'

type GymScore = {
  total: number
  raw: number
  reliability: number
  strength: number
  consistency: number
  volume: number
  progression: number
  variety: number
  quality: number
  sessions: number
  trainingDays: number
}

type SharedWorkoutPayload = {
  v: 1
  name: string
  description: string
  block?: string
  exercises: Array<Pick<Exercise, 'name' | 'sets' | 'reps' | 'weight' | 'rest'>>
}

const storageKey = 'gym-swipe-ios-state-v2'
const marketStorageKey = 'gym-swipe-ios-state-v3'
const legacyStorageKey = 'gym-swipe-ios-state-v1'
const xpRules = {
  set: 12,
  exerciseClosed: 18,
  pr: 75,
}

const demoWorkout: Exercise[] = [
  {
    id: 'mon-press-banca',
    day: 'Lunes',
    name: 'Press banca',
    targetSets: 4,
    sets: 4,
    completedSets: 0,
    skippedSets: 0,
    reps: 8,
    weight: 62.5,
    rest: 120,
    xp: 34,
    note: 'Pausa corta abajo',
    status: 'pending',
  },
  {
    id: 'mon-dominadas',
    day: 'Lunes',
    name: 'Dominadas lastradas',
    targetSets: 4,
    sets: 4,
    completedSets: 0,
    skippedSets: 0,
    reps: 6,
    weight: 7.5,
    rest: 150,
    xp: 42,
    note: 'Bajada controlada',
    status: 'pending',
  },
  {
    id: 'wed-sentadilla',
    day: 'Miércoles',
    name: 'Sentadilla frontal',
    targetSets: 5,
    sets: 5,
    completedSets: 0,
    skippedSets: 0,
    reps: 5,
    weight: 70,
    rest: 150,
    xp: 48,
    note: 'Core firme',
    status: 'pending',
  },
  {
    id: 'wed-rdl',
    day: 'Miércoles',
    name: 'Peso muerto rumano',
    targetSets: 3,
    sets: 3,
    completedSets: 0,
    skippedSets: 0,
    reps: 10,
    weight: 72.5,
    rest: 100,
    xp: 36,
    note: 'Espalda neutra',
    status: 'pending',
  },
  {
    id: 'fri-press-militar',
    day: 'Viernes',
    name: 'Press militar',
    targetSets: 4,
    sets: 4,
    completedSets: 0,
    skippedSets: 0,
    reps: 7,
    weight: 40,
    rest: 120,
    xp: 38,
    note: 'Bloqueo limpio',
    status: 'pending',
  },
  {
    id: 'fri-row',
    day: 'Viernes',
    name: 'Remo con barra',
    targetSets: 4,
    sets: 4,
    completedSets: 0,
    skippedSets: 0,
    reps: 9,
    weight: 65,
    rest: 100,
    xp: 35,
    note: 'Tira con codos',
    status: 'pending',
  },
]

const defaultState: WorkoutState = {
  schemaVersion: 3,
  exercises: [],
  player: {
    xp: 260,
    streak: 7,
    focus: 82,
    hearts: 3,
  },
  lastAction: 'Listo para empezar',
  history: [],
  prs: {},
  savedWorkouts: [],
  hiddenWorkoutIds: [],
  profile: {
    photo: '',
    photoX: 50,
    photoY: 50,
    sex: '',
    age: '',
    country: 'España',
    city: 'Madrid',
    gym: 'Basic-Fit Gran Vía',
  },
  preferences: {
    units: 'kg',
    reduceMotion: false,
    coaching: true,
    sounds: true,
  },
  undoStack: [],
}

const templates: WorkoutTemplate[] = [
  {
    name: 'Rugby 7 AM/PM',
    description: '12 semanas: fuerza AM, cardio y sprint PM',
    exercises: [
      makeExercise({
        day: 'Lunes AM - Tren superior',
        name: 'Press banca RPE 8',
        sets: 4,
        reps: 5,
        weight: 70,
        note: 'Fuerza base. Mantén 1-2 reps en reserva.',
        rest: 150,
        idSuffix: 'rugby7-1',
      }),
      makeExercise({
        day: 'Lunes AM - Tren superior',
        name: 'Remo con barra RPE 8',
        sets: 4,
        reps: 6,
        weight: 65,
        note: 'Escápulas atrás, tronco sólido.',
        rest: 135,
        idSuffix: 'rugby7-2',
      }),
      makeExercise({
        day: 'Lunes PM - Z2/Z3',
        name: 'Spinning Z2-Z3 fijo',
        sets: 1,
        reps: 35,
        weight: 0,
        note: 'Cardio estable separado de fuerza.',
        rest: 60,
        idSuffix: 'rugby7-3',
      }),
      makeExercise({
        day: 'Martes AM - Pierna',
        name: 'Sentadilla trasera RPE 8',
        sets: 5,
        reps: 4,
        weight: 90,
        note: 'Pierna pesada. No llegar a fallo.',
        rest: 180,
        idSuffix: 'rugby7-4',
      }),
      makeExercise({
        day: 'Martes AM - Pierna',
        name: 'Peso muerto rumano RPE 7.5',
        sets: 4,
        reps: 6,
        weight: 85,
        note: 'Isquios y cadera, bajada controlada.',
        rest: 150,
        idSuffix: 'rugby7-5',
      }),
      makeExercise({
        day: 'Martes PM - Sprint',
        name: 'Sprints aceleración',
        sets: 8,
        reps: 1,
        weight: 0,
        note: 'Siempre PM. Recupera completo entre salidas.',
        rest: 90,
        idSuffix: 'rugby7-6',
      }),
      makeExercise({
        day: 'Miércoles AM - Hipertrofia',
        name: 'Press militar RPE 8',
        sets: 4,
        reps: 6,
        weight: 42.5,
        note: 'Bloqueo limpio y core firme.',
        rest: 120,
        idSuffix: 'rugby7-7',
      }),
      makeExercise({
        day: 'Miércoles AM - Superserie',
        name: 'Elevación lateral + rear delt fly',
        sets: 3,
        reps: 15,
        weight: 10,
        note: 'Superserie de accesorios, descanso corto.',
        rest: 60,
        idSuffix: 'rugby7-8',
      }),
      makeExercise({
        day: 'Miércoles PM - Core/cuello',
        name: 'Core antirotación + cuello',
        sets: 4,
        reps: 12,
        weight: 0,
        note: 'Control cervical y estabilidad para contacto.',
        rest: 60,
        idSuffix: 'rugby7-9',
      }),
      makeExercise({
        day: 'Jueves PM - Z2/Z3',
        name: 'Spinning Z2-Z3 fijo',
        sets: 1,
        reps: 40,
        weight: 0,
        note: 'Mantener conversación corta, sin quemar piernas.',
        rest: 60,
        idSuffix: 'rugby7-10',
      }),
      makeExercise({
        day: 'Viernes AM - Pierna',
        name: 'Sentadilla frontal RPE 8',
        sets: 4,
        reps: 5,
        weight: 75,
        note: 'Segunda pierna de la semana.',
        rest: 165,
        idSuffix: 'rugby7-11',
      }),
      makeExercise({
        day: 'Viernes AM - Pierna',
        name: 'Hip thrust RPE 8',
        sets: 4,
        reps: 8,
        weight: 110,
        note: 'Extensión potente, pausa arriba.',
        rest: 120,
        idSuffix: 'rugby7-12',
      }),
      makeExercise({
        day: 'Viernes PM - Sprint',
        name: 'Sprints velocidad máxima',
        sets: 6,
        reps: 1,
        weight: 0,
        note: 'PM separado de fuerza. Calidad antes que fatiga.',
        rest: 120,
        idSuffix: 'rugby7-13',
      }),
      makeExercise({
        day: 'Sábado AM - Accesorios',
        name: 'Curl martillo + pushdown',
        sets: 3,
        reps: 12,
        weight: 17.5,
        note: 'Superserie de brazos, RPE 7.5-8.',
        rest: 60,
        idSuffix: 'rugby7-14',
      }),
      makeExercise({
        day: 'Sábado PM - Movilidad',
        name: 'Movilidad cadera/torácica',
        sets: 1,
        reps: 20,
        weight: 0,
        note: 'Descarga. Cada 4-5 semanas baja volumen y carga.',
        rest: 45,
        idSuffix: 'rugby7-15',
      }),
    ],
  },
  {
    name: 'Fuerza 3 dias',
    description: 'Basicos, progresion simple',
    workout: `Lunes
Press banca 4x6 65kg
Remo con barra 4x8 62.5kg
Sentadilla frontal 4x5 70kg

Miércoles
Peso muerto rumano 3x8 80kg
Press militar 4x6 40kg
Dominadas 4x6 0kg

Viernes
Sentadilla trasera 5x5 85kg
Press inclinado 3x8 52.5kg
Face pull 3x15 20kg`,
  },
  {
    name: 'Hipertrofia limpia',
    description: 'Volumen moderado, facil de seguir',
    workout: `Push
Press inclinado 4x8 52.5kg
Aperturas polea 3x12 12.5kg
Press militar 3x10 32.5kg

Pull
Dominadas 4x8 0kg
Remo mancuerna 3x10 30kg
Curl barra 3x12 25kg

Legs
Prensa 4x10 140kg
Peso muerto rumano 3x10 70kg
Gemelos 4x14 60kg`,
  },
  {
    name: 'Full body 2 dias',
    description: 'Simple, poco volumen',
    workout: `Dia A
Sentadilla goblet 4x8 32kg
Press banca 4x6 65kg
Remo mancuerna 4x8 30kg
Plancha 3x30 0kg

Dia B
Peso muerto rumano 4x8 75kg
Press militar 4x6 40kg
Dominadas 4x6 0kg
Zancadas 3x10 20kg`,
  },
  {
    name: 'Potencia rugby',
    description: 'Fuerza, saltos, sprint',
    workout: `Lunes AM
Sentadilla trasera 5x3 95kg
Press banca 5x3 75kg
Remo con barra 4x5 70kg

Miércoles PM
Saltos cajón 5x3 0kg
Sprints 8x1 0kg
Core antirotación 4x10 0kg

Viernes AM
Peso muerto 5x3 115kg
Press militar 4x5 45kg
Hip thrust 4x6 115kg`,
  },
  {
    name: 'Torso A',
    description: 'Empuje, tirón y hombro',
    workout: `Torso A
Press banca con barra 4x6 70kg
Remo con barra 4x8 65kg
Press militar 3x8 42.5kg
Dominadas 4x6 0kg
Elevacion lateral 3x14 10kg
Pushdown de triceps 3x12 25kg`,
  },
  {
    name: 'Pierna A',
    description: 'Sentadilla, bisagra y gluteo',
    workout: `Pierna A
Sentadilla con barra 5x5 90kg
Peso muerto rumano 4x8 80kg
Prensa de piernas 3x10 140kg
Hip thrust con barra 4x8 110kg
Curl femoral 3x12 45kg
Elevacion de gemelos 4x14 60kg`,
  },
  {
    name: 'Push compacto',
    description: 'Pecho, hombro y triceps',
    workout: `Push
Press banca inclinado con mancuernas 4x8 30kg
Press de hombros con mancuernas 4x8 22.5kg
Press banca con barra 3x6 70kg
Elevacion lateral 4x12 10kg
Fondos 3x8 0kg
Extension de triceps 3x12 25kg`,
  },
  {
    name: 'Pull compacto',
    description: 'Espalda y biceps',
    workout: `Pull
Dominadas 4x6 0kg
Remo con barra 4x8 65kg
Jalon dorsal 3x10 55kg
Face pull 3x15 20kg
Curl martillo 3x12 17.5kg
Curl de biceps 3x10 25kg`,
  },
  {
    name: 'Pierna explosiva',
    description: 'Potencia y tren inferior',
    workout: `Pierna explosiva
Sentadilla frontal 4x4 75kg
Salto al cajon 5x3 0kg
Peso muerto rumano 3x6 85kg
Zancadas 3x10 22.5kg
Sprints 8x1 0kg
Plancha 3x45 0kg`,
  },
  {
    name: 'Full body rapido',
    description: 'Sesion completa en poco tiempo',
    workout: `Full body rapido
Sentadilla goblet 3x10 32kg
Press banca con mancuernas 3x10 27.5kg
Remo mancuerna 3x10 30kg
Peso muerto rumano 3x8 75kg
Press militar 3x8 40kg
Plancha 3x40 0kg`,
  },
  {
    name: 'Acondicionamiento rugby',
    description: 'Cardio, sprint y core',
    workout: `Acondicionamiento
Spinning Z2-Z3 1x35 0kg
Sprints aceleracion 8x1 0kg
Sled push 6x1 0kg
Giro ruso 3x20 0kg
Core antirotacion 4x12 0kg
Movilidad cadera toracica 1x15 0kg`,
  },
]

function createId(seed: string) {
  return seed
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '')
}

function normalizeSearchText(value: string) {
  return value
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
}

function getExerciseSuggestionKey(name: string) {
  return normalizeSearchText(name.replace(/\s*\([^)]*\)/g, '').replace(/\s+-\s+.*/, '').trim())
}

function getWorkoutBlock(workout: Pick<WorkoutTemplate, 'block'> & { source?: WorkoutLibraryItem['source'] }) {
  const block = workout.block?.trim()

  if (block) {
    return block
  }

  return workout.source === 'template' ? 'Por defecto' : 'Mis entrenos'
}

function cloneExercises(exercises: Exercise[]) {
  return exercises.map((exercise) => ({ ...exercise }))
}

function cloneWorkout(workout: WorkoutTemplate): WorkoutTemplate {
  return {
    ...workout,
    exercises: workout.exercises ? cloneExercises(workout.exercises).map((exercise) => normalizeExercise(exercise)) : undefined,
  }
}

function encodeBase64Url(value: string) {
  const bytes = new TextEncoder().encode(value)
  let binary = ''
  bytes.forEach((byte) => {
    binary += String.fromCharCode(byte)
  })

  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

function decodeBase64Url(value: string) {
  const normalized = value.replace(/-/g, '+').replace(/_/g, '/')
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, '=')
  const binary = atob(padded)
  const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0))

  return new TextDecoder().decode(bytes)
}

function getExercisesFromWorkout(workout: WorkoutTemplate) {
  return workout.exercises ?? parseWorkout(workout.workout ?? '')
}

function createSharedWorkoutPayload(workout: WorkoutTemplate): SharedWorkoutPayload {
  return {
    v: 1,
    name: workout.name,
    description: workout.description,
    block: workout.block,
    exercises: getExercisesFromWorkout(workout).map((exercise) => ({
      name: exercise.name,
      sets: exercise.sets,
      reps: exercise.reps,
      weight: exercise.weight,
      rest: exercise.rest,
    })),
  }
}

function createWorkoutFromShare(payload: SharedWorkoutPayload): WorkoutTemplate {
  return {
    name: payload.name || 'Entrenamiento compartido',
    description: payload.description || `${payload.exercises.length} ejercicios`,
    block: payload.block || 'Compartidos',
    exercises: payload.exercises.map((exercise, index) =>
      makeExercise({
        ...exercise,
        day: payload.name || 'Compartido',
        idSuffix: `shared-${Date.now()}-${index}`,
      }),
    ),
  }
}

function createWorkoutShareUrl(workout: WorkoutTemplate) {
  const payload = createSharedWorkoutPayload(workout)
  const encoded = encodeBase64Url(JSON.stringify(payload))
  const base = window.location.origin + window.location.pathname

  return `${base}#workout=${encoded}`
}

function getSharedWorkoutFromHash() {
  const hash = window.location.hash.replace(/^#/, '')

  if (!hash.startsWith('workout=')) {
    return null
  }

  try {
    const payload = JSON.parse(decodeBase64Url(hash.replace('workout=', ''))) as SharedWorkoutPayload

    if (payload.v !== 1 || !Array.isArray(payload.exercises) || !payload.exercises.length) {
      return null
    }

    return createWorkoutFromShare(payload)
  } catch {
    return null
  }
}

function getClosedSets(exercise: Pick<Exercise, 'sets' | 'completedSets' | 'skippedSets'>) {
  return Math.min(exercise.sets, exercise.completedSets + exercise.skippedSets)
}

function getStatusFromSets(exercise: Pick<Exercise, 'sets' | 'completedSets' | 'skippedSets'>): ExerciseStatus {
  if (getClosedSets(exercise) < exercise.sets) {
    return 'pending'
  }

  return exercise.completedSets > 0 ? 'done' : 'skipped'
}

function normalizeExercise(exercise: Exercise): Exercise {
  const completedSets =
    typeof exercise.completedSets === 'number'
      ? exercise.completedSets
      : exercise.status === 'done'
        ? exercise.sets
        : 0
  const skippedSets =
    typeof exercise.skippedSets === 'number'
      ? exercise.skippedSets
      : exercise.status === 'skipped'
        ? exercise.sets
        : 0
  const normalized = {
    ...exercise,
    completedSets: Math.max(0, Math.min(exercise.sets, completedSets)),
    skippedSets: Math.max(0, Math.min(exercise.sets, skippedSets)),
  }
  const overflow = Math.max(0, normalized.completedSets + normalized.skippedSets - normalized.sets)

  if (overflow > 0) {
    normalized.skippedSets = Math.max(0, normalized.skippedSets - overflow)
  }

  return {
    ...normalized,
    status: getStatusFromSets(normalized),
  }
}

function snapshot(current: WorkoutState): Snapshot {
  return {
    exercises: cloneExercises(current.exercises),
    player: { ...current.player },
    lastAction: current.lastAction,
    history: [...current.history],
    prs: { ...current.prs },
    preferences: { ...current.preferences },
    profile: { ...current.profile },
    savedWorkouts: current.savedWorkouts.map(cloneWorkout),
    hiddenWorkoutIds: [...current.hiddenWorkoutIds],
  }
}

function withUndo(current: WorkoutState) {
  return [...current.undoStack.slice(-4), snapshot(current)]
}

function hydrateState(parsed: Partial<WorkoutState>): WorkoutState {
  const exercises = Array.isArray(parsed.exercises)
    ? parsed.exercises.map((exercise) => normalizeExercise(exercise))
    : demoWorkout

  return {
    schemaVersion: 3,
    exercises,
    player: parsed.player ?? defaultState.player,
    lastAction: parsed.lastAction ?? defaultState.lastAction,
    history: Array.isArray(parsed.history) ? parsed.history : [],
    prs: parsed.prs ?? {},
    savedWorkouts: Array.isArray(parsed.savedWorkouts) ? parsed.savedWorkouts.map(cloneWorkout) : [],
    hiddenWorkoutIds: Array.isArray(parsed.hiddenWorkoutIds) ? parsed.hiddenWorkoutIds : [],
    profile: {
      ...defaultState.profile,
      ...(parsed.profile ?? {}),
    },
    preferences: {
      ...defaultState.preferences,
      ...(parsed.preferences ?? {}),
      sounds: true,
    },
    undoStack: Array.isArray(parsed.undoStack) ? parsed.undoStack : [],
  }
}

function loadState(): WorkoutState {
  try {
    const rawState =
      localStorage.getItem(marketStorageKey) ??
      localStorage.getItem(storageKey) ??
      localStorage.getItem(legacyStorageKey)

    if (!rawState) {
      return defaultState
    }

    return hydrateState(JSON.parse(rawState) as Partial<WorkoutState>)
  } catch {
    return defaultState
  }
}

function parseWorkout(text: string): Exercise[] {
  const lines = text
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean)

  let currentDay = 'Hoy'

  return lines
    .map((line, index) => {
      const hasSetPattern = /\d+\s*x\s*\d+/i.test(line)
      const dayLine = !hasSetPattern && !/\d/.test(line)

      if (dayLine) {
        currentDay = line
        return null
      }

      const match = line.match(
        /^(?<name>.*?)(?<sets>\d+)\s*x\s*(?<reps>\d+)(?:\s+(?<weight>\d+(?:[.,]\d+)?)\s*(?:kg|kilos)?)?$/i,
      )

      const name = match?.groups?.name.trim().replace(/[-:]+$/, '').trim() || line
      const sets = Number(match?.groups?.sets ?? 3)
      const reps = Number(match?.groups?.reps ?? 8)
      const weight = Number((match?.groups?.weight ?? 0).toString().replace(',', '.'))

      return makeExercise({
        day: currentDay,
        name,
        sets,
        reps,
        weight,
        idSuffix: String(index),
      })
    })
    .filter((exercise): exercise is Exercise => Boolean(exercise))
}

function makeExercise({
  day,
  name,
  sets,
  reps,
  weight,
  rest,
  xp,
  note,
  idSuffix = String(Date.now()),
}: NewExercise & { day: string; rest?: number; xp?: number; note?: string; idSuffix?: string }): Exercise {
  return {
    id: `${createId(day)}-${createId(name)}-${idSuffix}`,
    day,
    name,
    targetSets: sets,
    sets,
    completedSets: 0,
    skippedSets: 0,
    reps,
    weight,
    rest: rest ?? 90 + Math.min(60, sets * 10),
    xp: xp ?? 20 + Math.min(40, sets * reps),
    note: note ?? 'Sin nota',
    status: 'pending',
  }
}

function formatTimer(seconds: number) {
  const minutes = Math.floor(seconds / 60)
  const remaining = seconds % 60
  return `${minutes}:${remaining.toString().padStart(2, '0')}`
}

function formatElapsed(seconds: number) {
  const hours = Math.floor(seconds / 3600)
  const minutes = Math.floor((seconds % 3600) / 60)
  const remaining = seconds % 60

  if (hours > 0) {
    return `${hours}:${minutes.toString().padStart(2, '0')}:${remaining.toString().padStart(2, '0')}`
  }

  return `${minutes}:${remaining.toString().padStart(2, '0')}`
}

function getSetVolume(exercise: Pick<Exercise, 'reps' | 'weight'>) {
  return exercise.reps * exercise.weight
}

function clampScore(value: number) {
  return Math.max(0, Math.min(100, Math.round(value)))
}

function getExercisePattern(name: string) {
  const normalized = normalizeSearchText(name)

  if (/sentadilla|prensa|zancada|pierna|gemelo/.test(normalized)) {
    return { group: 'pierna', benchmark: 120, compound: 1.08 }
  }

  if (/peso muerto|rumano|hip thrust/.test(normalized)) {
    return { group: 'bisagra', benchmark: 145, compound: 1.12 }
  }

  if (/press banca|fondos|press inclinado|aperturas/.test(normalized)) {
    return { group: 'empuje', benchmark: 92.5, compound: 1.05 }
  }

  if (/remo|dominada|jalon|pull/.test(normalized)) {
    return { group: 'tiron', benchmark: 82.5, compound: 1.04 }
  }

  if (/core|plancha|abdominal|ruso|antirotacion|movilidad|spinning|sprint|sled/.test(normalized)) {
    return { group: 'condicion', benchmark: 40, compound: 0.72 }
  }

  return { group: 'accesorio', benchmark: 45, compound: 0.82 }
}

function getEstimatedOneRepMax(entry: Pick<HistoryEntry, 'weight' | 'reps'>) {
  return entry.weight * (1 + Math.min(20, entry.reps) / 30)
}

function getWeightedRecentEntries(history: HistoryEntry[], days: number) {
  const now = Date.now()
  const dayMs = 24 * 60 * 60 * 1000

  return history
    .filter((entry) => entry.status === 'done')
    .map((entry) => {
      const ageDays = Math.max(0, (now - new Date(entry.completedAt).getTime()) / dayMs)
      return {
        entry,
        ageDays,
        weight: Math.max(0, 1 - ageDays / days),
      }
    })
    .filter((item) => item.ageDays <= days)
}

function calculateGymScore(history: HistoryEntry[]): GymScore {
  const recent = getWeightedRecentEntries(history, 21)
  const previous = getWeightedRecentEntries(history, 42).filter((item) => item.ageDays > 21)
  const recentEntries = recent.map((item) => item.entry)
  const recentSessions = new Set(recentEntries.map((entry) => entry.sessionId ?? entry.completedAt.slice(0, 10)))
  const recentDays = new Set(recentEntries.map((entry) => entry.completedAt.slice(0, 10)))
  const groups = new Set(recentEntries.map((entry) => getExercisePattern(entry.exerciseName).group))
  const skippedRecent = history.filter((entry) => {
    const ageDays = Math.max(0, (Date.now() - new Date(entry.completedAt).getTime()) / (24 * 60 * 60 * 1000))
    return ageDays <= 21 && entry.status === 'skipped'
  })
  const weightedVolume = recent.reduce((total, item) => {
    const pattern = getExercisePattern(item.entry.exerciseName)
    return total + item.entry.volume * pattern.compound * item.weight
  }, 0)
  const previousVolume = previous.reduce((total, item) => total + item.entry.volume * item.weight, 0)
  const bestByGroup = new Map<string, number>()

  recent.forEach(({ entry }) => {
    const pattern = getExercisePattern(entry.exerciseName)
    if (entry.weight <= 0) {
      return
    }

    const normalizedStrength = (getEstimatedOneRepMax(entry) / pattern.benchmark) * 100
    bestByGroup.set(pattern.group, Math.max(bestByGroup.get(pattern.group) ?? 0, normalizedStrength))
  })

  const strength = bestByGroup.size
    ? clampScore(Array.from(bestByGroup.values()).reduce((total, value) => total + Math.min(130, value), 0) / bestByGroup.size)
    : 0
  const consistency = clampScore((recentDays.size / 12) * 100)
  const volume = clampScore(Math.log10(weightedVolume + 1) * 21)
  const progressionBase = previousVolume > 0 ? ((weightedVolume - previousVolume) / previousVolume) * 70 + 50 : recentEntries.length ? 58 : 0
  const progression = clampScore(progressionBase)
  const variety = clampScore((groups.size / 5) * 100)
  const completionRate = recentEntries.length / Math.max(1, recentEntries.length + skippedRecent.length)
  const quality = clampScore(completionRate * 72 + Math.min(28, strength * 0.22))
  const raw =
    strength * 0.35 +
    consistency * 0.2 +
    volume * 0.15 +
    progression * 0.15 +
    variety * 0.1 +
    quality * 0.05
  const reliability = Math.min(1, recentSessions.size / 6)
  const total = clampScore(raw * (0.55 + reliability * 0.45))

  return {
    total,
    raw: clampScore(raw),
    reliability: Math.round(reliability * 100),
    strength,
    consistency,
    volume,
    progression,
    variety,
    quality,
    sessions: recentSessions.size,
    trainingDays: recentDays.size,
  }
}

function getRankingRows(score: GymScore, scope: RankingScope) {
  const labels: Record<RankingScope, string[]> = {
    global: ['Mika', 'Leo', 'Sofia', 'Tú', 'Alex', 'Nora'],
    country: ['Dani', 'Carlos', 'Tú', 'Marina', 'Iker', 'Luna'],
    city: ['Rafa', 'Tú', 'Julia', 'Adri', 'Vera', 'Noa'],
    zone: ['Tú', 'Pablo', 'Marta', 'Hugo', 'Laia', 'Enzo'],
  }
  const offsets: Record<RankingScope, number[]> = {
    global: [24, 16, 9, 0, -4, -11],
    country: [13, 6, 0, -5, -9, -14],
    city: [8, 0, -3, -7, -12, -16],
    zone: [0, -2, -6, -10, -13, -18],
  }

  return labels[scope]
    .map((name, index) => ({
      name,
      score: clampScore((score.total || 42) + offsets[scope][index]),
      isYou: name === 'Tú',
    }))
    .sort((first, second) => second.score - first.score)
}

function getScopeLabel(scope: RankingScope) {
  return scope === 'global' ? 'Global' : scope === 'country' ? 'España' : scope === 'city' ? 'Madrid' : 'Zona'
}

type MapUser = {
  id: string
  name: string
  scope: RankingScope
  level: string
  goal: string
  score: number
  lat: number
  lng: number
  area: string
}

type MapPoint = {
  lat: number
  lng: number
}

const fallbackMapPoint: MapPoint = { lat: 40.4168, lng: -3.7038 }

const mapUsers: MapUser[] = [
  { id: 'global-nyc', name: 'Usuario Nueva York', scope: 'global', level: 'Avanzado', goal: 'Fuerza', score: 88, lat: 40.72, lng: -74.02, area: 'zona Manhattan' },
  { id: 'global-mex', name: 'Usuario CDMX', scope: 'global', level: 'Intermedio', goal: 'Hipertrofia', score: 76, lat: 19.43, lng: -99.13, area: 'zona Roma Norte' },
  { id: 'global-bali', name: 'Usuario Bali', scope: 'global', level: 'Avanzado', goal: 'Cross training', score: 83, lat: -8.65, lng: 115.14, area: 'zona Canggu' },
  { id: 'global-london', name: 'Usuario Londres', scope: 'global', level: 'Intermedio', goal: 'Estética', score: 71, lat: 51.51, lng: -0.12, area: 'zona Shoreditch' },
  { id: 'country-valencia', name: 'Usuario Valencia', scope: 'country', level: 'Intermedio', goal: 'Hipertrofia', score: 74, lat: 39.47, lng: -0.37, area: 'zona Ruzafa' },
  { id: 'country-barcelona', name: 'Usuario Barcelona', scope: 'country', level: 'Avanzado', goal: 'Powerlifting', score: 84, lat: 41.39, lng: 2.17, area: 'zona Eixample' },
  { id: 'country-sevilla', name: 'Usuario Sevilla', scope: 'country', level: 'Principiante', goal: 'Pérdida de grasa', score: 58, lat: 37.39, lng: -5.99, area: 'zona Nervión' },
  { id: 'country-bilbao', name: 'Usuario Bilbao', scope: 'country', level: 'Intermedio', goal: 'Fuerza', score: 69, lat: 43.26, lng: -2.94, area: 'zona Indautxu' },
  { id: 'city-chamberi', name: 'Usuario cerca de Chamberí', scope: 'city', level: 'Intermedio', goal: 'Hipertrofia', score: 73, lat: 40.43, lng: -3.7, area: 'Chamberí' },
  { id: 'city-retiro', name: 'Entrena por Retiro', scope: 'city', level: 'Intermedio-avanzado', goal: 'Running + gym', score: 79, lat: 40.41, lng: -3.68, area: 'Retiro' },
  { id: 'city-malasana', name: 'Usuario Malasaña', scope: 'city', level: 'Intermedio', goal: 'Estética', score: 68, lat: 40.43, lng: -3.71, area: 'Malasaña' },
  { id: 'city-salamanca', name: 'Usuario Salamanca', scope: 'city', level: 'Avanzado', goal: 'Fuerza', score: 82, lat: 40.43, lng: -3.68, area: 'Salamanca' },
  { id: 'zone-centro', name: 'Usuario cerca de Centro', scope: 'zone', level: 'Intermedio', goal: 'Calistenia', score: 72, lat: 40.416, lng: -3.704, area: 'Madrid centro' },
  { id: 'zone-arguelles', name: 'Usuario Argüelles', scope: 'zone', level: 'Intermedio', goal: 'Hipertrofia', score: 70, lat: 40.429, lng: -3.715, area: 'Argüelles' },
  { id: 'zone-lavapies', name: 'Usuario Lavapiés', scope: 'zone', level: 'Principiante', goal: 'Pérdida de grasa', score: 55, lat: 40.409, lng: -3.7, area: 'Lavapiés' },
]

type MapViewport = {
  center: MapPoint
  zoom: number
  width: number
  height: number
}

type MapTile = {
  id: string
  src: string
  left: number
  top: number
}

type MapCluster = {
  id: string
  x: number
  y: number
  count: number
  users: MapUser[]
}

const mapTileSize = 256
const mapViewportSize = {
  width: 334,
  height: 354,
}

function getScopeZoom(scope: RankingScope) {
  return scope === 'global' ? 1 : scope === 'country' ? 5 : scope === 'city' ? 11 : 13
}

function getMapCenter(scope: RankingScope, userPoint: MapPoint): MapPoint {
  if (scope === 'global') {
    return { lat: 22, lng: 8 }
  }

  return userPoint
}

function getMapViewport(scope: RankingScope, userPoint: MapPoint): MapViewport {
  return {
    center: getMapCenter(scope, userPoint),
    zoom: getScopeZoom(scope),
    ...mapViewportSize,
  }
}

function pointToWorldPixel(point: MapPoint, zoom: number) {
  const scale = mapTileSize * 2 ** zoom
  const sinLat = Math.sin((Math.max(-85.0511, Math.min(85.0511, point.lat)) * Math.PI) / 180)

  return {
    x: ((point.lng + 180) / 360) * scale,
    y: (0.5 - Math.log((1 + sinLat) / (1 - sinLat)) / (4 * Math.PI)) * scale,
  }
}

function worldPixelToPoint(pixel: { x: number; y: number }, zoom: number): MapPoint {
  const scale = mapTileSize * 2 ** zoom
  const lng = (pixel.x / scale) * 360 - 180
  const n = Math.PI - (2 * Math.PI * pixel.y) / scale
  const lat = (180 / Math.PI) * Math.atan(0.5 * (Math.exp(n) - Math.exp(-n)))

  return { lat, lng }
}

function projectMapPoint(point: MapPoint, viewport: MapViewport) {
  const center = pointToWorldPixel(viewport.center, viewport.zoom)
  const projected = pointToWorldPixel(point, viewport.zoom)

  return {
    x: projected.x - (center.x - viewport.width / 2),
    y: projected.y - (center.y - viewport.height / 2),
  }
}

function getClusterRadius(scope: RankingScope) {
  return scope === 'global' ? 34 : scope === 'country' ? 30 : scope === 'city' ? 24 : 20
}

function getMapClusters(users: MapUser[], viewport: MapViewport, scope: RankingScope): MapCluster[] {
  const radius = getClusterRadius(scope)
  const clusters: MapCluster[] = []

  users.forEach((user) => {
    const point = projectMapPoint(user, viewport)
    const existing = clusters.find((cluster) => {
      const distance = Math.hypot(cluster.x - point.x, cluster.y - point.y)
      return distance <= radius
    })

    if (existing) {
      existing.users.push(user)
      existing.count += 1
      existing.x += (point.x - existing.x) / existing.count
      existing.y += (point.y - existing.y) / existing.count
      return
    }

    clusters.push({
      id: user.id,
      x: point.x,
      y: point.y,
      count: 1,
      users: [user],
    })
  })

  return clusters
}

function getMapTiles(viewport: MapViewport): MapTile[] {
  const center = pointToWorldPixel(viewport.center, viewport.zoom)
  const topLeft = {
    x: center.x - viewport.width / 2,
    y: center.y - viewport.height / 2,
  }
  const startX = Math.floor(topLeft.x / mapTileSize)
  const endX = Math.floor((topLeft.x + viewport.width) / mapTileSize)
  const startY = Math.floor(topLeft.y / mapTileSize)
  const endY = Math.floor((topLeft.y + viewport.height) / mapTileSize)
  const tileCount = 2 ** viewport.zoom
  const tiles: MapTile[] = []

  for (let x = startX; x <= endX; x += 1) {
    for (let y = startY; y <= endY; y += 1) {
      if (y < 0 || y >= tileCount) {
        continue
      }

      const wrappedX = ((x % tileCount) + tileCount) % tileCount
      tiles.push({
        id: `${viewport.zoom}-${x}-${y}`,
        src: `https://tile.openstreetmap.org/${viewport.zoom}/${wrappedX}/${y}.png`,
        left: x * mapTileSize - topLeft.x,
        top: y * mapTileSize - topLeft.y,
      })
    }
  }

  return tiles
}

function getVisibleMapUsers(scope: RankingScope) {
  const scopeRank: Record<RankingScope, number> = {
    global: 0,
    country: 1,
    city: 2,
    zone: 3,
  }

  return mapUsers.filter((user) => scopeRank[user.scope] >= scopeRank[scope])
}

function getMapScopeCopy(scope: RankingScope) {
  return scope === 'global'
    ? 'Todo el mundo'
    : scope === 'country'
      ? 'España'
      : scope === 'city'
        ? 'Ciudad'
        : 'Área cercana'
}

function getCountryFlag(country: string) {
  const normalized = normalizeSearchText(country)

  if (normalized.includes('espana') || normalized.includes('spain')) {
    return '🇪🇸'
  }

  if (normalized.includes('mexico')) {
    return '🇲🇽'
  }

  if (normalized.includes('argentina')) {
    return '🇦🇷'
  }

  if (normalized.includes('colombia')) {
    return '🇨🇴'
  }

  if (normalized.includes('chile')) {
    return '🇨🇱'
  }

  if (normalized.includes('usa') || normalized.includes('estados unidos')) {
    return '🇺🇸'
  }

  return '🌍'
}

type TrainingPlanDraft = {
  when: string
  date: string
  where: string[]
  workout: string
  level: string
  spots: string
}

type TrainingPlanCard = TrainingPlanDraft & {
  id: string
  title: string
  place: string
  intensity: string
  objective: string
  note: string
}

const trainingPlansStorageKey = 'gym-swipe-training-plans-v1'
const defaultTrainingPlanDraft: TrainingPlanDraft = {
  when: 'Mañana',
  date: '',
  where: ['Mi gimnasio'],
  workout: 'Pecho',
  level: 'Similar al mío',
  spots: '1 persona',
}
const planWhenOptions = ['Hoy', 'Mañana', 'Esta semana', 'Fecha concreta']
const planWhereOptions = ['Mi gimnasio', 'Cerca de mí', 'Parque / calistenia']
const planWorkoutOptions = ['Pecho', 'Espalda', 'Pierna', 'Push', 'Pull', 'Full body', 'Calistenia', 'Cardio', 'Otro']
const planLevelOptions = ['Cualquiera', 'Similar al mío', 'Más avanzado', 'Principiante friendly']
const planSpotOptions = ['1 persona', '2 personas', 'Grupo pequeño', 'Me adapto']

const defaultTrainingPlans: TrainingPlanCard[] = [
  {
    id: 'plan-demo-push',
    title: 'Pecho + tríceps',
    when: 'Mañana',
    date: '',
    where: ['Mi gimnasio'],
    workout: 'Pecho',
    level: 'Similar al mío',
    spots: '1 persona',
    place: 'Basic-Fit Gran Vía',
    intensity: 'Fuerte',
    objective: 'Hipertrofia',
    note: '',
  },
  {
    id: 'plan-demo-legs',
    title: 'Pierna',
    when: 'Esta semana',
    date: '',
    where: ['Cerca de mí'],
    workout: 'Pierna',
    level: 'Cualquiera',
    spots: '2 personas',
    place: 'Zona cercana',
    intensity: 'Media-alta',
    objective: 'Fuerza + volumen',
    note: '',
  },
]

function getPlanPlace(where: string[], profile: Profile) {
  if (where.includes('Mi gimnasio')) {
    return profile.gym || 'Mi gimnasio'
  }

  if (where.includes('Parque / calistenia')) {
    return 'Parque cercano'
  }

  return 'Zona cercana'
}

function getPlanObjective(workout: string) {
  if (workout === 'Cardio') {
    return 'Resistencia'
  }

  if (workout === 'Calistenia') {
    return 'Control corporal'
  }

  if (workout === 'Pierna') {
    return 'Fuerza + volumen'
  }

  return 'Hipertrofia'
}

function getPlanIntensity(level: string) {
  return level === 'Más avanzado' ? 'Fuerte' : level === 'Principiante friendly' ? 'Moderada' : 'Media-alta'
}

function createTrainingPlan(draft: TrainingPlanDraft, profile: Profile): TrainingPlanCard {
  const title = draft.workout === 'Pecho' ? 'Pecho + tríceps' : draft.workout === 'Espalda' ? 'Espalda + bíceps' : draft.workout
  const when = draft.when === 'Fecha concreta' && draft.date ? new Date(`${draft.date}T12:00:00`).toLocaleDateString('es-ES', { day: '2-digit', month: 'short' }) : draft.when

  return {
    ...draft,
    id: `plan-${Date.now()}`,
    title,
    when,
    place: getPlanPlace(draft.where, profile),
    intensity: getPlanIntensity(draft.level),
    objective: getPlanObjective(draft.workout),
    note: '',
  }
}

function loadTrainingPlans() {
  try {
    const raw = localStorage.getItem(trainingPlansStorageKey)
    if (!raw) {
      return defaultTrainingPlans
    }

    const parsed = JSON.parse(raw) as TrainingPlanCard[]
    return Array.isArray(parsed)
      ? parsed.map((plan) => ({ ...plan, where: Array.isArray(plan.where) ? plan.where : [String(plan.where)] }))
      : defaultTrainingPlans
  } catch {
    return defaultTrainingPlans
  }
}


function getXpForLevel(level: number) {
  if (level <= 1) {
    return 0
  }

  return Math.round(120 * (Math.pow(level - 1, 1.42) + (level - 2) * 0.38))
}

function getLevelProgress(xp: number) {
  let level = 1

  while (xp >= getXpForLevel(level + 1)) {
    level += 1
  }

  const currentLevelXp = getXpForLevel(level)
  const nextLevelXp = getXpForLevel(level + 1)
  const earnedInLevel = xp - currentLevelXp
  const neededInLevel = Math.max(1, nextLevelXp - currentLevelXp)

  return {
    level,
    currentLevelXp,
    nextLevelXp,
    earnedInLevel,
    neededInLevel,
    progress: Math.min(100, Math.round((earnedInLevel / neededInLevel) * 100)),
  }
}

function getWorkoutNameFromExercises(exercises: Exercise[]) {
  const firstDay = exercises[0]?.day

  if (!firstDay) {
    return 'Entreno'
  }

  return firstDay.replace(/\s+(AM|PM)\b.*$/i, '').replace(/\s+-\s+.*$/, '').trim() || 'Entreno'
}

function getDayStreak(history: HistoryEntry[]) {
  const doneDays = new Set(
    history
      .filter((entry) => entry.status === 'done')
      .map((entry) => entry.completedAt.slice(0, 10)),
  )
  let streak = 0
  const cursor = new Date()
  cursor.setHours(12, 0, 0, 0)

  while (doneDays.has(cursor.toISOString().slice(0, 10))) {
    streak += 1
    cursor.setDate(cursor.getDate() - 1)
  }

  return streak
}

function getDemoAchievementHistory(history: HistoryEntry[]): HistoryEntry[] {
  const realDateKeys = new Set(history.map((entry) => entry.completedAt.slice(0, 10)))
  const today = new Date()
  today.setHours(18, 30, 0, 0)

  return [2, 5, 8, 12].flatMap((daysAgo, sessionIndex) => {
    const date = new Date(today)
    date.setDate(today.getDate() - daysAgo)
    const dateKey = date.toISOString().slice(0, 10)

    if (realDateKeys.has(dateKey)) {
      return []
    }

    const sessionId = `demo-session-${dateKey}`
    const workoutName = ['Torso A', 'Pierna explosiva', 'Push compacto', 'Full body rapido'][sessionIndex]
    const exercises = [
      ['Press banca', 3, 8, 70],
      ['Remo con barra', 3, 10, 62.5],
      ['Sentadilla frontal', 4, 6, 75],
      ['Plancha', 2, 40, 0],
    ] as const

    return exercises.map(([exerciseName, totalSets, reps, weight], index): HistoryEntry => {
      const completedAtDate = new Date(date)
      completedAtDate.setMinutes(date.getMinutes() + index * 7)
      const skipped = sessionIndex === 1 && index === 3

      return {
        id: `${sessionId}-${index}`,
        exerciseId: `${sessionId}-${createId(exerciseName)}`,
        exerciseName,
        day: workoutName,
        status: skipped ? 'skipped' : 'done',
        sets: 1,
        reps,
        weight,
        volume: skipped ? 0 : reps * weight,
        xp: skipped ? 0 : xpRules.set,
        completedAt: completedAtDate.toISOString(),
        isPr: false,
        sessionId,
        workoutName,
        sessionStartedAt: date.toISOString(),
        sessionElapsedSeconds: 38 * 60 + sessionIndex * 280,
        setIndex: index + 1,
        totalSetsInExercise: totalSets,
        setDurationSeconds: skipped ? 0 : 42 + index * 5,
        restBeforeSeconds: index === 0 ? 0 : 85 + index * 8,
        exerciseRestSeconds: 90,
      }
    })
  })
}

function getTabFromHash(): Tab {
  const hash = window.location.hash.replace('#', '')
  if (hash === 'progress' || hash === 'achievements' || hash === 'settings') {
    return 'profile'
  }

  return hash === 'plan' || hash === 'ranking' || hash === 'partner' || hash === 'profile' ? hash : 'train'
}

function App() {
  const [state, setState] = useState<WorkoutState>(loadState)
  const [activeTab, setActiveTab] = useState<Tab>(getTabFromHash)
  const [restRemaining, setRestRemaining] = useState(0)
  const [celebration, setCelebration] = useState<Celebration | null>(null)
  const [mascotReaction, setMascotReaction] = useState<MascotMood | null>(null)
  const [sessionStartedAt, setSessionStartedAt] = useState(() => Date.now())
  const [elapsedSeconds, setElapsedSeconds] = useState(0)
  const [sessionStatus, setSessionStatus] = useState<SessionStatus>('ready')
  const [draftWorkoutName, setDraftWorkoutName] = useState('Mi entrenamiento')
  const [draftWorkoutBlock, setDraftWorkoutBlock] = useState('Mis entrenos')
  const [draftExercises, setDraftExercises] = useState<DraftExercise[]>([])
  const [newExercise, setNewExercise] = useState<NewExercise>({
    name: '',
    sets: 3,
    reps: 8,
    weight: 0,
  })
  const [dragX, setDragX] = useState(0)
  const [dragging, setDragging] = useState(false)
  const [swipeExit, setSwipeExit] = useState<Exclude<ExerciseStatus, 'pending'> | null>(null)
  const startX = useRef(0)
  const deckRef = useRef<HTMLDivElement>(null)
  const audioContextRef = useRef<AudioContext | null>(null)
  const swipeExitRef = useRef<Exclude<ExerciseStatus, 'pending'> | null>(null)
  const swipeCommitTimer = useRef<number | null>(null)
  const dragXRef = useRef(0)
  const startY = useRef(0)
  const swipeGestureRef = useRef<'idle' | 'horizontal' | 'vertical'>('idle')
  const sessionIdRef = useRef(`session-${Date.now()}`)
  const setStartedAtRef = useRef(Date.now())
  const lastSetClosedAtRef = useRef<number | null>(null)
  const importedShareRef = useRef('')

  const pending = useMemo(
    () => state.exercises.filter((exercise) => exercise.status === 'pending'),
    [state.exercises],
  )
  const active = pending[0]
  const doneSets = state.exercises.reduce((total, exercise) => total + exercise.completedSets, 0)
  const skippedSets = state.exercises.reduce((total, exercise) => total + exercise.skippedSets, 0)
  const completed = doneSets + skippedSets
  const totalPlannedSets = state.exercises.reduce((total, exercise) => total + exercise.sets, 0)
  const swipeIntent = swipeExit ?? (dragX > 36 ? 'done' : dragX < -36 ? 'skipped' : 'idle')
  const workouts = useMemo<WorkoutLibraryItem[]>(
    () => [
      ...templates.map((workout, index) => ({
        ...workout,
        block: workout.block ?? 'Por defecto',
        libraryId: `template-${createId(workout.name)}-${index}`,
        source: 'template' as const,
        removable: true,
      })),
      ...state.savedWorkouts.map((workout, index) => ({
        ...workout,
        block: workout.block ?? 'Mis entrenos',
        libraryId: `saved-${createId(workout.name)}-${index}`,
        source: 'saved' as const,
        removable: true,
      })),
    ].filter((workout) => !state.hiddenWorkoutIds.includes(workout.libraryId)),
    [state.hiddenWorkoutIds, state.savedWorkouts],
  )

  useEffect(() => {
    localStorage.setItem(marketStorageKey, JSON.stringify(state))
  }, [state])

  useEffect(() => {
    const onHashChange = () => setActiveTab(getTabFromHash())
    window.addEventListener('hashchange', onHashChange)
    return () => window.removeEventListener('hashchange', onHashChange)
  }, [])

  useEffect(() => {
    const hash = window.location.hash
    const sharedWorkout = getSharedWorkoutFromHash()

    if (!sharedWorkout || importedShareRef.current === hash) {
      return
    }

    importedShareRef.current = hash
    setState((current) => {
      const exists = current.savedWorkouts.some((workout) => workout.name === sharedWorkout.name)

      return {
        ...current,
        savedWorkouts: exists ? current.savedWorkouts : [...current.savedWorkouts, sharedWorkout],
        lastAction: `${sharedWorkout.name} importado`,
      }
    })
    setActiveTab('plan')
  }, [])

  useEffect(() => {
    if (restRemaining <= 0) {
      return
    }

    const timerId = window.setInterval(() => {
      setRestRemaining((current) => Math.max(0, current - 1))
    }, 1000)

    return () => window.clearInterval(timerId)
  }, [restRemaining])

  useEffect(() => {
    if (sessionStatus !== 'active') {
      return
    }

    const timerId = window.setInterval(() => {
      setElapsedSeconds(Math.floor((Date.now() - sessionStartedAt) / 1000))
    }, 1000)

    return () => window.clearInterval(timerId)
  }, [sessionStatus, sessionStartedAt])

  useEffect(() => {
    if (!celebration) {
      return
    }

    const timerId = window.setTimeout(() => setCelebration(null), 1250)
    return () => window.clearTimeout(timerId)
  }, [celebration])

  useEffect(() => {
    if (!mascotReaction) {
      return
    }

    const timerId = window.setTimeout(() => setMascotReaction(null), 950)
    return () => window.clearTimeout(timerId)
  }, [mascotReaction])

  function playFeedback(type: SoundCue) {
    if (!state.preferences.sounds) {
      return
    }

    const AudioContextConstructor =
      window.AudioContext ??
      (window as Window & { webkitAudioContext?: typeof AudioContext }).webkitAudioContext

    if (!AudioContextConstructor) {
      return
    }

    const context = audioContextRef.current ?? new AudioContextConstructor()
    audioContextRef.current = context
    const soundMap: Record<SoundCue, { notes: number[]; step: number; duration: number; gain: number; oscillator: OscillatorType }> = {
      tap: { notes: [392, 523.25], step: 0.045, duration: 0.045, gain: 0.035, oscillator: 'sine' },
      tick: { notes: [587.33], step: 0.045, duration: 0.045, gain: 0.035, oscillator: 'sine' },
      set: { notes: [659.25], step: 0.045, duration: 0.07, gain: 0.055, oscillator: 'sine' },
      done: { notes: [659.25], step: 0.045, duration: 0.07, gain: 0.055, oscillator: 'sine' },
      skipped: { notes: [196, 164.81], step: 0.07, duration: 0.09, gain: 0.06, oscillator: 'triangle' },
      exercise: { notes: [261.63, 329.63, 392, 523.25, 659.25], step: 0.075, duration: 0.16, gain: 0.095, oscillator: 'square' },
      pr: { notes: [523.25, 659.25, 783.99, 1046.5], step: 0.055, duration: 0.12, gain: 0.09, oscillator: 'sine' },
      start: { notes: [392, 493.88, 587.33, 783.99], step: 0.055, duration: 0.12, gain: 0.075, oscillator: 'sine' },
      finish: { notes: [523.25, 659.25, 783.99, 987.77, 1046.5], step: 0.055, duration: 0.14, gain: 0.09, oscillator: 'sine' },
    }
    const playSound = () => {
      const now = context.currentTime
      const sound = soundMap[type]

      sound.notes.forEach((frequency, index) => {
        const oscillator = context.createOscillator()
        const gain = context.createGain()
        const start = now + index * sound.step

        oscillator.type = sound.oscillator
        oscillator.frequency.setValueAtTime(frequency, start)
        gain.gain.setValueAtTime(0.0001, start)
        gain.gain.exponentialRampToValueAtTime(sound.gain, start + 0.012)
        gain.gain.exponentialRampToValueAtTime(0.0001, start + sound.duration)
        oscillator.connect(gain)
        gain.connect(context.destination)
        oscillator.start(start)
        oscillator.stop(start + sound.duration + 0.02)
      })
    }

    if (context.state === 'suspended') {
      void context.resume().then(playSound).catch(() => undefined)
      return
    }

    playSound()
  }

  function triggerFeedback(type: Celebration['type'], message: string, value?: string, soundCue: SoundCue = type) {
    playFeedback(soundCue)
    navigator.vibrate?.(type === 'pr' ? [18, 28, 18] : type === 'done' ? 18 : 10)
    setMascotReaction(type === 'pr' ? 'pr' : type === 'done' ? 'cheer' : 'miss')
    setCelebration({
      id: Date.now(),
      type,
      message,
      value,
    })
  }

  function updateActive(patch: Partial<Exercise>) {
    if (!active) {
      return
    }

    playFeedback('tick')
    setState((current) => ({
      ...current,
      exercises: current.exercises.map((exercise) =>
        exercise.id === active.id
          ? normalizeExercise({
              ...exercise,
              ...patch,
              completedSets: Math.min(exercise.completedSets, patch.sets ?? exercise.sets),
              skippedSets: Math.min(
                exercise.skippedSets,
                Math.max(0, (patch.sets ?? exercise.sets) - Math.min(exercise.completedSets, patch.sets ?? exercise.sets)),
              ),
            })
          : exercise,
      ),
    }))
  }

  function completeExercise(status: Exclude<ExerciseStatus, 'pending'>) {
    if (!active) {
      return
    }

    const nextCompletedSets = active.completedSets + (status === 'done' ? 1 : 0)
    const nextSkippedSets = active.skippedSets + (status === 'skipped' ? 1 : 0)
    const closesExercise = nextCompletedSets + nextSkippedSets >= active.sets
    const finishesWorkout = closesExercise && pending.length === 1
    const completedVolume = getSetVolume(active) * nextCompletedSets
    const willBePr =
      status === 'done' &&
      closesExercise &&
      nextCompletedSets === active.sets &&
      (!state.prs[active.name] || completedVolume > state.prs[active.name].volume)

    if (status === 'done' && !finishesWorkout) {
      setRestRemaining(active.rest)
    }

    triggerFeedback(
      finishesWorkout ? 'done' : status === 'done' ? (willBePr ? 'pr' : 'done') : 'skipped',
      finishesWorkout
        ? 'Entreno finalizado'
        : willBePr
        ? `Nuevo PR: ${active.name}`
        : status === 'done'
          ? `Serie ${nextCompletedSets + active.skippedSets}/${active.sets}: ${active.name}`
          : `Serie ${active.completedSets + nextSkippedSets}/${active.sets} saltada`,
      status === 'done' ? `+${xpRules.set} XP` : undefined,
      finishesWorkout ? 'finish' : closesExercise ? 'exercise' : status === 'done' ? 'set' : 'skipped',
    )

    setState((current) => {
      const currentActive = current.exercises.find((exercise) => exercise.status === 'pending')

      if (!currentActive) {
        return current
      }

      const completedAt = new Date().toISOString()
      const completedAtMs = Date.now()
      const nextExercise = normalizeExercise({
        ...currentActive,
        completedSets: currentActive.completedSets + (status === 'done' ? 1 : 0),
        skippedSets: currentActive.skippedSets + (status === 'skipped' ? 1 : 0),
      })
      const volume = status === 'done' ? getSetVolume(currentActive) : 0
      const completedExerciseVolume = getSetVolume(currentActive) * nextExercise.completedSets
      const previousPr = current.prs[currentActive.name]
      const isPr =
        status === 'done' &&
        nextExercise.status === 'done' &&
        nextExercise.completedSets === nextExercise.sets &&
        (!previousPr || completedExerciseVolume > previousPr.volume)
      const nextStreak = status === 'done' ? current.player.streak + 1 : 0
      const exerciseBonus =
        status === 'done' && nextExercise.status === 'done' && nextExercise.skippedSets === 0
          ? xpRules.exerciseClosed
          : 0
      const prBonus = isPr ? xpRules.pr : 0
      const setXp = status === 'done' ? xpRules.set + exerciseBonus + prBonus : 0
      const setDurationSeconds = Math.max(1, Math.round((completedAtMs - setStartedAtRef.current) / 1000))
      const restBeforeSeconds = lastSetClosedAtRef.current
        ? Math.max(0, Math.round((setStartedAtRef.current - lastSetClosedAtRef.current) / 1000))
        : 0
      const historyEntry: HistoryEntry = {
        id: `${currentActive.id}-${completedAt}`,
        exerciseId: currentActive.id,
        exerciseName: currentActive.name,
        day: currentActive.day,
        status,
        sets: 1,
        reps: currentActive.reps,
        weight: currentActive.weight,
        volume,
        xp: status === 'done' ? setXp : 0,
        completedAt,
        isPr,
        sessionId: sessionIdRef.current,
        workoutName: getWorkoutNameFromExercises(current.exercises),
        sessionStartedAt: new Date(sessionStartedAt).toISOString(),
        sessionElapsedSeconds: Math.max(0, Math.floor((completedAtMs - sessionStartedAt) / 1000)),
        setIndex: getClosedSets(nextExercise),
        totalSetsInExercise: currentActive.sets,
        setDurationSeconds,
        restBeforeSeconds,
        exerciseRestSeconds: currentActive.rest,
      }
      lastSetClosedAtRef.current = completedAtMs
      setStartedAtRef.current = completedAtMs

      return {
        ...current,
        exercises: current.exercises.map((exercise) =>
          exercise.id === currentActive.id ? nextExercise : exercise,
        ),
        player: {
          xp: current.player.xp + setXp,
          streak: status === 'done' ? nextStreak : 0,
          focus:
            status === 'done'
              ? Math.min(100, current.player.focus + 3)
              : Math.max(0, current.player.focus - 8),
          hearts:
            status === 'done' ? current.player.hearts : Math.max(0, current.player.hearts - 1),
        },
        history: [historyEntry, ...current.history].slice(0, 300),
        prs:
          isPr && status === 'done'
            ? {
                ...current.prs,
                [currentActive.name]: {
                  exerciseName: currentActive.name,
                  weight: currentActive.weight,
                  reps: currentActive.reps,
                  sets: nextExercise.completedSets,
                  volume: completedExerciseVolume,
                  date: completedAt,
                },
              }
            : current.prs,
        lastAction:
          finishesWorkout
            ? 'Entreno finalizado'
            : status === 'done'
            ? isPr
              ? `Nuevo PR en ${currentActive.name}`
              : nextExercise.status === 'done'
                ? `${currentActive.name} cerrado`
                : `Serie ${getClosedSets(nextExercise)}/${nextExercise.sets} hecha`
            : nextExercise.status === 'skipped'
              ? `${currentActive.name} pasado`
              : `Serie ${getClosedSets(nextExercise)}/${nextExercise.sets} saltada`,
        undoStack: withUndo(current),
      }
    })
    if (finishesWorkout) {
      setRestRemaining(0)
      setElapsedSeconds(Math.max(0, Math.floor((Date.now() - sessionStartedAt) / 1000)))
      setSessionStatus('finished')
    }
    dragXRef.current = 0
    setDragX(0)
    setDragging(false)
  }

  function undoLastAction() {
    setState((current) => {
      const previous = current.undoStack.at(-1)

      if (!previous) {
        return current
      }

      return {
        schemaVersion: 3,
        ...previous,
        savedWorkouts: previous.savedWorkouts ?? current.savedWorkouts,
        hiddenWorkoutIds: previous.hiddenWorkoutIds ?? current.hiddenWorkoutIds,
        profile: previous.profile ?? current.profile,
        undoStack: current.undoStack.slice(0, -1),
        lastAction: 'Acción deshecha',
      }
    })
    setRestRemaining(0)
  }

  function applyTemplate(template: WorkoutTemplate) {
    const parsed = template.exercises ? cloneExercises(template.exercises) : parseWorkout(template.workout ?? '')

    if (!parsed.length) {
      return
    }

    setState((current) => ({
      ...current,
      exercises: parsed,
      lastAction: `${template.name} cargada`,
      undoStack: withUndo(current),
    }))
    selectTab('train')
    playFeedback('tap')
    setRestRemaining(0)
    sessionIdRef.current = `session-${Date.now()}`
    setStartedAtRef.current = Date.now()
    lastSetClosedAtRef.current = null
    setSessionStartedAt(Date.now())
    setElapsedSeconds(0)
    setSessionStatus('ready')
  }

  function updateProfilePhoto(file: File | null) {
    if (!file) {
      return
    }

    const reader = new FileReader()
    reader.onload = () => {
      setState((current) => ({
        ...current,
        profile: {
          ...current.profile,
          photo: typeof reader.result === 'string' ? reader.result : '',
        },
        lastAction: 'Perfil actualizado',
      }))
      playFeedback('finish')
    }
    reader.readAsDataURL(file)
  }


  function updateProfile(patch: Partial<Profile>) {
    setState((current) => ({
      ...current,
      profile: {
        ...current.profile,
        ...patch,
      },
      lastAction: 'Perfil actualizado',
    }))
  }

  function selectTab(tab: Tab) {
    if (tab !== activeTab) {
      playFeedback('tap')
    }

    window.location.hash = tab === 'train' ? '' : tab
    setActiveTab(tab)
  }

  function startSession() {
    if (!active) {
      selectTab('plan')
      return
    }

    const now = Date.now()
    sessionIdRef.current = `session-${now}`
    setStartedAtRef.current = now
    lastSetClosedAtRef.current = null
    setSessionStartedAt(now)
    setElapsedSeconds(0)
    setSessionStatus('active')
    setRestRemaining(0)
    playFeedback('start')
    navigator.vibrate?.([12, 22, 12])
    setState((current) => ({
      ...current,
      lastAction: 'Entreno iniciado',
    }))
  }

  function finishSession() {
    if (sessionStatus !== 'active') {
      return
    }

    const finishedAtMs = Date.now()
    const finishedAt = new Date(finishedAtMs).toISOString()
    const finalElapsedSeconds = Math.floor((finishedAtMs - sessionStartedAt) / 1000)

    setElapsedSeconds(finalElapsedSeconds)
    setSessionStatus('finished')
    setRestRemaining(0)
    playFeedback('finish')
    navigator.vibrate?.([18, 24, 18, 24, 18])
    setState((current) => {
      const workoutName = getWorkoutNameFromExercises(current.exercises)
      const skippedEntries = current.exercises.flatMap((exercise) => {
        const closedSets = getClosedSets(exercise)
        const pendingSets = Math.max(0, exercise.sets - closedSets)

        return Array.from({ length: pendingSets }).map((_, index): HistoryEntry => ({
          id: `${exercise.id}-${finishedAt}-unfinished-${index}`,
          exerciseId: exercise.id,
          exerciseName: exercise.name,
          day: exercise.day,
          status: 'skipped',
          sets: 1,
          reps: exercise.reps,
          weight: exercise.weight,
          volume: 0,
          xp: 0,
          completedAt: finishedAt,
          isPr: false,
          sessionId: sessionIdRef.current,
          workoutName,
          sessionStartedAt: new Date(sessionStartedAt).toISOString(),
          sessionElapsedSeconds: finalElapsedSeconds,
          setIndex: closedSets + index + 1,
          totalSetsInExercise: exercise.sets,
          setDurationSeconds: 0,
          restBeforeSeconds: 0,
          exerciseRestSeconds: exercise.rest,
        }))
      })

      return {
        ...current,
        exercises: current.exercises.map((exercise) =>
          normalizeExercise({
            ...exercise,
            skippedSets: exercise.skippedSets + Math.max(0, exercise.sets - getClosedSets(exercise)),
          }),
        ),
        history: [...skippedEntries, ...current.history].slice(0, 300),
        lastAction: 'Entreno finalizado',
      }
    })
  }

  function addDraftExercise() {
    if (!newExercise.name.trim()) {
      return
    }

    playFeedback('done')
    const exercise: DraftExercise = {
      ...newExercise,
      id: `${Date.now()}-${createId(newExercise.name)}`,
      name: newExercise.name.trim(),
      sets: Math.max(1, newExercise.sets),
      reps: Math.max(1, newExercise.reps),
      weight: Math.max(0, newExercise.weight),
    }

    setDraftExercises((current) => [...current, exercise])
    setNewExercise((current) => ({ ...current, name: '' }))
  }

  function removeDraftExercise(id: string) {
    playFeedback('tap')
    setDraftExercises((current) => current.filter((exercise) => exercise.id !== id))
  }

  function saveDraftWorkout(editingWorkout?: WorkoutLibraryItem | null) {
    if (!draftExercises.length) {
      return
    }

    const workoutName = draftWorkoutName.trim() || 'Entrenamiento'
    const workoutBlock = draftWorkoutBlock.trim() || 'Mis entrenos'
    const exercises = draftExercises.map((exercise, index) =>
      makeExercise({
        ...exercise,
        day: workoutName,
        idSuffix: `custom-${Date.now()}-${index}`,
      }),
    )
    const savedWorkout: WorkoutTemplate = {
      name: workoutName,
      description: `${draftExercises.length} ejercicios`,
      block: workoutBlock,
      exercises,
    }

    setState((current) => ({
      ...current,
      savedWorkouts: [
        ...current.savedWorkouts.filter(
          (workout) => workout.name !== workoutName && workout.name !== editingWorkout?.name,
        ),
        savedWorkout,
      ],
      hiddenWorkoutIds:
        editingWorkout?.source === 'template' && !current.hiddenWorkoutIds.includes(editingWorkout.libraryId)
          ? [...current.hiddenWorkoutIds, editingWorkout.libraryId]
          : current.hiddenWorkoutIds,
      lastAction: `${workoutName} guardado`,
    }))
    playFeedback('finish')
    setDraftExercises([])
    setDraftWorkoutName('Mi entrenamiento')
    setDraftWorkoutBlock('Mis entrenos')
    setNewExercise({
      name: '',
      sets: 3,
      reps: 8,
      weight: 0,
    })
  }

  function deleteWorkout(workout: WorkoutLibraryItem) {
    playFeedback('skipped')
    setState((current) => ({
      ...current,
      savedWorkouts:
        workout.source === 'saved'
          ? current.savedWorkouts.filter((savedWorkout) => savedWorkout.name !== workout.name)
          : current.savedWorkouts,
      hiddenWorkoutIds:
        workout.source === 'template' && !current.hiddenWorkoutIds.includes(workout.libraryId)
          ? [...current.hiddenWorkoutIds, workout.libraryId]
          : current.hiddenWorkoutIds,
      lastAction: `${workout.name} eliminado`,
    }))
  }

  function onPointerDown(event: PointerEvent<HTMLDivElement>) {
    if (!active || swipeExitRef.current) {
      return
    }

    startX.current = event.clientX
    startY.current = event.clientY
    dragXRef.current = 0
    swipeGestureRef.current = 'idle'
  }

  function onPointerMove(event: PointerEvent<HTMLDivElement>) {
    if (!active || swipeExitRef.current) {
      return
    }

    const nextX = event.clientX - startX.current
    const nextY = event.clientY - startY.current

    if (swipeGestureRef.current === 'idle') {
      if (Math.abs(nextX) < 10 && Math.abs(nextY) < 10) {
        return
      }

      if (Math.abs(nextY) > Math.abs(nextX) * 1.15) {
        swipeGestureRef.current = 'vertical'
        setDragging(false)
        dragXRef.current = 0
        setDragX(0)
        return
      }

      swipeGestureRef.current = 'horizontal'
      setDragging(true)
      deckRef.current?.setPointerCapture(event.pointerId)
    }

    if (swipeGestureRef.current !== 'horizontal') {
      return
    }

    event.preventDefault()
    const clampedX = Math.max(-220, Math.min(220, nextX))
    dragXRef.current = clampedX
    setDragX(clampedX)
  }

  function finishSwipe(status: Exclude<ExerciseStatus, 'pending'>) {
    if (swipeExitRef.current) {
      return
    }

    swipeExitRef.current = status
    setSwipeExit(status)
    setDragging(false)

    if (swipeCommitTimer.current) {
      window.clearTimeout(swipeCommitTimer.current)
    }

    window.requestAnimationFrame(() => {
      window.requestAnimationFrame(() => {
        const exitX = Math.max(620, window.innerWidth + 260)
        dragXRef.current = status === 'done' ? exitX : -exitX
        setDragX(status === 'done' ? exitX : -exitX)
      })
    })

    swipeCommitTimer.current = window.setTimeout(() => commitSwipeExit(status), 520)
  }

  function commitSwipeExit(status = swipeExitRef.current) {
    if (!status) {
      return
    }

    if (swipeCommitTimer.current) {
      window.clearTimeout(swipeCommitTimer.current)
      swipeCommitTimer.current = null
    }

    swipeExitRef.current = null
    completeExercise(status)
    dragXRef.current = 0
    swipeGestureRef.current = 'idle'
    setSwipeExit(null)
  }

  function onSwipeExitTransitionEnd(event: TransitionEvent<HTMLDivElement>) {
    if (event.propertyName !== 'transform') {
      return
    }

    commitSwipeExit()
  }

  function onPointerUp() {
    if (swipeGestureRef.current !== 'horizontal' || !dragging || swipeExitRef.current) {
      swipeGestureRef.current = 'idle'
      return
    }

    const currentDragX = dragXRef.current

    if (currentDragX > 96) {
      finishSwipe('done')
      return
    }

    if (currentDragX < -96) {
      finishSwipe('skipped')
      return
    }

    dragXRef.current = 0
    swipeGestureRef.current = 'idle'
    setDragX(0)
    setDragging(false)
  }

  return (
    <main className="app-shell">
      <section
        className={`phone-stage ${activeTab === 'train' ? 'training-stage' : ''} ${state.preferences.reduceMotion ? 'reduce-motion' : ''}`}
        aria-label="Forge Loop"
      >
        <div className="art-strip" aria-hidden="true" />
        <CelebrationToast celebration={celebration} />

        <header className="top-bar">
          <div>
            <p className="eyebrow">Forge Loop</p>
            <h1>
              {activeTab === 'train'
                ? 'Entreno'
                : activeTab === 'plan'
                  ? 'Plan'
                  : activeTab === 'ranking'
                  ? 'Ranking'
                  : activeTab === 'partner'
                    ? 'Partner'
                    : 'Perfil'}
            </h1>
          </div>
        </header>

        <nav className="tab-bar" aria-label="Vistas">
          <TabButton active={activeTab === 'train'} icon={<Dumbbell size={16} />} label="Entreno" onClick={() => selectTab('train')} />
          <TabButton active={activeTab === 'plan'} icon={<ListChecks size={16} />} label="Plan" onClick={() => selectTab('plan')} />
          <TabButton active={activeTab === 'ranking'} icon={<Globe2 size={16} />} label="Ranking" onClick={() => selectTab('ranking')} />
          <TabButton active={activeTab === 'partner'} icon={<Users size={16} />} label="Partner" onClick={() => selectTab('partner')} />
          <TabButton active={activeTab === 'profile'} icon={<UserRound size={16} />} label="Perfil" onClick={() => selectTab('profile')} />
        </nav>

        <section key={activeTab} className={`screen-body view-${activeTab}`}>
          {activeTab === 'train' && (
            <TrainView
              active={active}
              completed={completed}
              total={totalPlannedSets}
              dragX={dragX}
              dragging={dragging}
              swipeExit={swipeExit}
              mascotReaction={mascotReaction}
              elapsedSeconds={elapsedSeconds}
              sessionStatus={sessionStatus}
              restRemaining={restRemaining}
              swipeIntent={swipeIntent}
              deckRef={deckRef}
              canUndo={state.undoStack.length > 0}
              onPointerDown={onPointerDown}
              onPointerMove={onPointerMove}
              onPointerUp={onPointerUp}
              onSwipeExitTransitionEnd={onSwipeExitTransitionEnd}
              onUpdateActive={updateActive}
              onComplete={completeExercise}
              onUndo={undoLastAction}
              onStart={startSession}
              onFinish={finishSession}
              onSelectWorkout={() => selectTab('plan')}
              onAddRest={() => setRestRemaining((current) => current + 15)}
              onSkipRest={() => setRestRemaining(0)}
            />
          )}

          {activeTab === 'plan' && (
            <PlanView
              draftWorkoutName={draftWorkoutName}
              setDraftWorkoutName={setDraftWorkoutName}
              draftWorkoutBlock={draftWorkoutBlock}
              setDraftWorkoutBlock={setDraftWorkoutBlock}
              draftExercises={draftExercises}
              setDraftExercises={setDraftExercises}
              newExercise={newExercise}
              setNewExercise={setNewExercise}
              workouts={workouts}
              onApplyTemplate={applyTemplate}
              onAddExercise={addDraftExercise}
              onRemoveExercise={removeDraftExercise}
              onSaveWorkout={saveDraftWorkout}
              onDeleteWorkout={deleteWorkout}
            />
          )}

          {activeTab === 'ranking' && (
            <RankingView history={state.history} profile={state.profile} />
          )}

          {activeTab === 'partner' && (
            <PartnerView profile={state.profile} />
          )}

          {activeTab === 'profile' && (
            <ProfileView
              player={state.player}
              profile={state.profile}
              history={state.history}
              onPhotoChange={updateProfilePhoto}
              onProfileChange={updateProfile}
            />
          )}
        </section>
      </section>
    </main>
  )
}

function TrainView({
  active,
  completed,
  total,
  dragX,
  dragging,
  swipeExit,
  mascotReaction,
  elapsedSeconds,
  sessionStatus,
  restRemaining,
  swipeIntent,
  deckRef,
  canUndo,
  onPointerDown,
  onPointerMove,
  onPointerUp,
  onSwipeExitTransitionEnd,
  onUpdateActive,
  onComplete,
  onUndo,
  onStart,
  onFinish,
  onSelectWorkout,
  onAddRest,
  onSkipRest,
}: {
  active: Exercise | undefined
  completed: number
  total: number
  dragX: number
  dragging: boolean
  swipeExit: Exclude<ExerciseStatus, 'pending'> | null
  mascotReaction: MascotMood | null
  elapsedSeconds: number
  sessionStatus: SessionStatus
  restRemaining: number
  swipeIntent: 'done' | 'skipped' | 'idle'
  deckRef: React.RefObject<HTMLDivElement | null>
  canUndo: boolean
  onPointerDown: (event: PointerEvent<HTMLDivElement>) => void
  onPointerMove: (event: PointerEvent<HTMLDivElement>) => void
  onPointerUp: () => void
  onSwipeExitTransitionEnd: (event: TransitionEvent<HTMLDivElement>) => void
  onUpdateActive: (patch: Partial<Exercise>) => void
  onComplete: (status: Exclude<ExerciseStatus, 'pending'>) => void
  onUndo: () => void
  onStart: () => void
  onFinish: () => void
  onSelectWorkout: () => void
  onAddRest: () => void
  onSkipRest: () => void
}) {
  const progress = Math.round((completed / Math.max(1, total)) * 100)
  const hasWorkout = total > 0
  const activeClosedSets = active ? getClosedSets(active) : 0
  const latestClosedSetIndex = activeClosedSets - 1
  const currentSet = active ? Math.min(active.sets, activeClosedSets + 1) : 0
  const setXp = active ? Math.max(1, Math.round(active.xp / Math.max(1, active.sets))) : 0
  const isSessionActive = sessionStatus === 'active'
  const mascotMood: MascotMood =
    mascotReaction ??
    (sessionStatus === 'finished' ? 'finished' : sessionStatus === 'ready' ? 'ready' : restRemaining > 0 ? 'rest' : 'active')

  return (
    <>
      <section className={`training-session-card ${sessionStatus}`} aria-label="Sesión activa">
        <GymBuddy mood={mascotMood} compact />
        <div className="training-live-row">
          <span className="live-dot" aria-hidden="true" />
          <span>
            {sessionStatus === 'active'
              ? 'Entreno iniciado'
              : sessionStatus === 'finished'
                ? 'Entreno finalizado'
                : 'Preparado'}
          </span>
          <strong>{formatElapsed(elapsedSeconds)}</strong>
        </div>
        <div className="training-progress-row">
          <span>{hasWorkout ? `${completed}/${total} series` : 'Sin entreno'}</span>
          <div className="progress-track">
            <span style={{ width: `${progress}%` }} />
          </div>
        </div>
        {sessionStatus === 'active' && (
          <button className="finish-session-button" type="button" onClick={onFinish} disabled={!isSessionActive}>
            Finalizar
          </button>
        )}
      </section>

      {restRemaining > 0 && (
        <section className="rest-card" aria-label="Descanso">
          <div>
            <p>Descanso</p>
            <strong>{formatTimer(restRemaining)}</strong>
          </div>
          <button type="button" onClick={onAddRest}>+15s</button>
          <button type="button" onClick={onSkipRest}>Saltar</button>
        </section>
      )}

      <section className="deck-zone" aria-label="Ejercicio actual">
        {active ? (
          <article
            key={active.id}
            ref={deckRef}
            className={`exercise-card active ${dragging ? 'dragging' : ''} ${swipeExit ? 'exiting' : ''} intent-${swipeIntent}`}
            onPointerDown={onPointerDown}
            onPointerMove={onPointerMove}
            onPointerUp={onPointerUp}
            onPointerCancel={onPointerUp}
            onTransitionEnd={onSwipeExitTransitionEnd}
            style={{
              transform: `translateX(${dragX}px) rotate(${dragX / 18}deg)`,
            }}
          >
            <div className="decision-badge done">
              <Check size={16} />
            </div>
            <div className="decision-badge skipped">
              <X size={16} />
            </div>

            <div className="card-head">
              <div>
                <p className="exercise-day">{active.day}</p>
                <h2>{active.name}</h2>
              </div>
              <div className="chip-stack">
                <span className="set-chip">Serie {currentSet}/{active.sets}</span>
                <span className="xp-chip">+{setXp} XP</span>
              </div>
            </div>

            <div className="set-dots" aria-hidden="true">
              {Array.from({ length: Math.max(active.targetSets, active.sets) }).map((_, index) => {
                const isDoneSet = index < active.completedSets
                const isSkippedSet =
                  !isDoneSet && index < active.completedSets + active.skippedSets
                const isLatestSet = index === latestClosedSetIndex && (isDoneSet || isSkippedSet)

                return (
                  <span
                    key={`${active.id}-set-${index}`}
                    className={[
                      isDoneSet ? 'lit' : '',
                      isSkippedSet ? 'skipped' : '',
                      isLatestSet ? 'latest' : '',
                    ]
                      .filter(Boolean)
                      .join(' ')}
                  />
                )
              })}
            </div>

            <div className="metric-editor">
              <NumberControl
                label="Peso"
                value={active.weight}
                suffix="kg"
                step={2.5}
                onChange={(weight) => onUpdateActive({ weight })}
              />
              <NumberControl
                label="Reps"
                value={active.reps}
                suffix=""
                step={1}
                onChange={(reps) => onUpdateActive({ reps })}
              />
            </div>

          </article>
        ) : hasWorkout ? (
          <article className="complete-state">
            <p className="eyebrow">Terminado</p>
            <h2>Entreno finalizado</h2>
            <button className="primary-button" type="button" onClick={onSelectWorkout}>
              <ListChecks size={17} />
              Elegir otro entreno
            </button>
          </article>
        ) : (
          <article className="complete-state">
            <p className="eyebrow">Plan</p>
            <h2>Elige entreno</h2>
            <button className="primary-button" type="button" onClick={onSelectWorkout}>
              <ListChecks size={17} />
              Seleccionar
            </button>
          </article>
        )}
      </section>

      <nav className="action-dock" aria-label="Acciones">
        <button
          className="dock-button soft"
          type="button"
          onClick={onUndo}
          disabled={!canUndo}
          aria-label="Deshacer"
          title="Deshacer"
        >
          <Undo2 size={22} />
        </button>
        <button
          className="dock-button skip"
          type="button"
          onClick={() => onComplete('skipped')}
          disabled={!active || !isSessionActive}
          aria-label="Saltar serie"
          title="Saltar serie"
        >
          <X size={24} />
        </button>
        <button
          className="dock-button done"
          type="button"
          onClick={() => onComplete('done')}
          disabled={!active || !isSessionActive}
          aria-label="Marcar hecho"
          title="Marcar hecho"
        >
          <Check size={27} />
        </button>
      </nav>

      {sessionStatus === 'ready' && (
        <div className="start-session-overlay" role="presentation">
          <GymBuddy mood="ready" />
          <button className="start-session-button" type="button" onClick={hasWorkout ? onStart : onSelectWorkout}>
            {hasWorkout ? 'Iniciar entreno' : 'Seleccionar entreno'}
          </button>
        </div>
      )}

      {sessionStatus === 'finished' && (
        <div className="finish-session-overlay" role="status">
          <div className="finish-session-panel">
            <GymBuddy mood="finished" compact />
            <Check size={28} />
            <strong>Entreno finalizado</strong>
            <span>{formatElapsed(elapsedSeconds)}</span>
            <button type="button" onClick={onSelectWorkout}>Elegir otro entreno</button>
          </div>
        </div>
      )}
    </>
  )
}

function PlanView({
  draftWorkoutName,
  setDraftWorkoutName,
  draftWorkoutBlock,
  setDraftWorkoutBlock,
  draftExercises,
  setDraftExercises,
  newExercise,
  setNewExercise,
  workouts,
  onApplyTemplate,
  onAddExercise,
  onRemoveExercise,
  onSaveWorkout,
  onDeleteWorkout,
}: {
  draftWorkoutName: string
  setDraftWorkoutName: React.Dispatch<React.SetStateAction<string>>
  draftWorkoutBlock: string
  setDraftWorkoutBlock: React.Dispatch<React.SetStateAction<string>>
  draftExercises: DraftExercise[]
  setDraftExercises: React.Dispatch<React.SetStateAction<DraftExercise[]>>
  newExercise: NewExercise
  setNewExercise: React.Dispatch<React.SetStateAction<NewExercise>>
  workouts: WorkoutLibraryItem[]
  onApplyTemplate: (template: WorkoutTemplate) => void
  onAddExercise: () => void
  onRemoveExercise: (id: string) => void
  onSaveWorkout: (editingWorkout?: WorkoutLibraryItem | null) => void
  onDeleteWorkout: (workout: WorkoutLibraryItem) => void
}) {
  const trashRef = useRef<HTMLDivElement>(null)
  const suppressWorkoutClick = useRef(false)
  const longPressTimer = useRef<number | null>(null)
  const [draggedWorkout, setDraggedWorkout] = useState<{
    id: string
    workout: WorkoutLibraryItem
    startX: number
    startY: number
    clientX: number
    clientY: number
    active: boolean
    armed: boolean
    overTrash: boolean
  } | null>(null)
  const [previewWorkout, setPreviewWorkout] = useState<WorkoutLibraryItem | null>(null)
  const [planMode, setPlanMode] = useState<'library' | 'create'>('library')
  const [exerciseSearchOpen, setExerciseSearchOpen] = useState(false)
  const [editingWorkout, setEditingWorkout] = useState<WorkoutLibraryItem | null>(null)
  const [shareNotice, setShareNotice] = useState('')
  const customExerciseName = newExercise.name.trim()
  const previewExercises = useMemo(
    () =>
      previewWorkout
        ? previewWorkout.exercises ?? parseWorkout(previewWorkout.workout ?? '')
        : [],
    [previewWorkout],
  )
  const exerciseSuggestions = useMemo(() => {
    const query = normalizeSearchText(newExercise.name.trim())

    if (!query) {
      return exerciseCatalog.slice(0, 8)
    }

    const seen = new Set<string>()

    return exerciseCatalog
      .filter((exercise) => normalizeSearchText(`${exercise.name} ${exercise.originalName}`).includes(query))
      .sort((first, second) => {
        const firstName = normalizeSearchText(first.name)
        const secondName = normalizeSearchText(second.name)
        const firstScore = firstName.startsWith(query) ? 0 : firstName.includes(query) ? 1 : 2
        const secondScore = secondName.startsWith(query) ? 0 : secondName.includes(query) ? 1 : 2

        return firstScore - secondScore || first.name.localeCompare(second.name, 'es')
      })
      .filter((exercise) => {
        const key = getExerciseSuggestionKey(exercise.name)

        if (seen.has(key)) {
          return false
        }

        seen.add(key)
        return true
      })
      .slice(0, 8)
  }, [newExercise.name])
  const workoutGroups = useMemo(() => {
    const groups = new Map<string, WorkoutLibraryItem[]>()

    workouts.forEach((workout) => {
      const block = getWorkoutBlock(workout)
      groups.set(block, [...(groups.get(block) ?? []), workout])
    })

    return Array.from(groups.entries()).map(([label, groupWorkouts]) => ({
      id: createId(label) || 'bloque',
      label,
      tag: `${groupWorkouts.length} entrenos`,
      workouts: groupWorkouts,
    }))
  }, [workouts])

  function startWorkoutDrag(event: PointerEvent<HTMLButtonElement>, workout: WorkoutLibraryItem) {
    if (!workout.removable) {
      return
    }

    if (longPressTimer.current) {
      window.clearTimeout(longPressTimer.current)
    }

    setDraggedWorkout({
      id: workout.libraryId,
      workout,
      startX: event.clientX,
      startY: event.clientY,
      clientX: event.clientX,
      clientY: event.clientY,
      active: false,
      armed: false,
      overTrash: false,
    })

    longPressTimer.current = window.setTimeout(() => {
      setDraggedWorkout((current) =>
        current && current.id === workout.libraryId
          ? {
              ...current,
              active: true,
              armed: true,
            }
          : current,
      )
      navigator.vibrate?.(12)
    }, 500)
  }

  function moveWorkoutDrag(event: PointerEvent<HTMLButtonElement>, workout: WorkoutLibraryItem) {
    if (!draggedWorkout || draggedWorkout.id !== workout.libraryId) {
      return
    }

    const x = event.clientX - draggedWorkout.startX
    const y = event.clientY - draggedWorkout.startY

    if (!draggedWorkout.armed) {
      if (Math.abs(x) + Math.abs(y) > 10) {
        if (longPressTimer.current) {
          window.clearTimeout(longPressTimer.current)
          longPressTimer.current = null
        }
        setDraggedWorkout(null)
      }
      return
    }

    event.currentTarget.setPointerCapture(event.pointerId)
    const trashBox = trashRef.current?.getBoundingClientRect()
    const overTrash =
      Boolean(trashBox) &&
      event.clientX >= trashBox!.left &&
      event.clientX <= trashBox!.right &&
      event.clientY >= trashBox!.top &&
      event.clientY <= trashBox!.bottom

    setDraggedWorkout((current) =>
      current && current.id === workout.libraryId
        ? {
            ...current,
            clientX: event.clientX,
            clientY: event.clientY,
            active: true,
            overTrash,
          }
        : current,
    )
  }

  function finishWorkoutDrag() {
    if (longPressTimer.current) {
      window.clearTimeout(longPressTimer.current)
      longPressTimer.current = null
    }

    if (!draggedWorkout) {
      return
    }

    if (draggedWorkout.active) {
      suppressWorkoutClick.current = true
      window.setTimeout(() => {
        suppressWorkoutClick.current = false
      }, 0)
    }

    if (draggedWorkout.active && draggedWorkout.overTrash) {
      onDeleteWorkout(draggedWorkout.workout)
      setPreviewWorkout((current) =>
        current?.libraryId === draggedWorkout.workout.libraryId ? null : current,
      )
    }

    setDraggedWorkout(null)
  }

  function selectWorkout(workout: WorkoutLibraryItem) {
    if (suppressWorkoutClick.current) {
      suppressWorkoutClick.current = false
      return
    }

    setShareNotice('')
    setPreviewWorkout(workout)
  }

  async function shareWorkout(workout: WorkoutLibraryItem) {
    const url = createWorkoutShareUrl(workout)
    const title = `${workout.name} · Forge Loop`

    try {
      if (navigator.share) {
        await navigator.share({ title, text: `Prueba este entreno: ${workout.name}`, url })
        setShareNotice('Enlace compartido')
        return
      }

      await navigator.clipboard.writeText(url)
      setShareNotice('Enlace copiado')
    } catch {
      setShareNotice('No se pudo compartir')
    }
  }

  function editWorkout(workout: WorkoutLibraryItem) {
    const exercises = workout.exercises ?? parseWorkout(workout.workout ?? '')

    setDraftWorkoutName(workout.name)
    setDraftWorkoutBlock(getWorkoutBlock(workout))
    setDraftExercises(
      exercises.map((exercise, index) => ({
        id: `${workout.libraryId}-edit-${index}`,
        name: exercise.name,
        sets: exercise.sets,
        reps: exercise.reps,
        weight: exercise.weight,
      })),
    )
    setNewExercise({
      name: '',
      sets: 3,
      reps: 8,
      weight: 0,
    })
    setEditingWorkout(workout)
    setPreviewWorkout(null)
    setPlanMode('create')
  }

  function updateDraftExercise(id: string, patch: Partial<NewExercise>) {
    setDraftExercises((current) =>
      current.map((exercise) =>
        exercise.id === id
          ? {
              ...exercise,
              ...patch,
              sets: Math.max(1, patch.sets ?? exercise.sets),
              reps: Math.max(1, patch.reps ?? exercise.reps),
              weight: Math.max(0, patch.weight ?? exercise.weight),
            }
          : exercise,
      ),
    )
  }

  if (planMode === 'create') {
    return (
      <section className="plan-view plan-create-view">
        <section className="plan-block add-panel">
          <div className="plan-panel-head">
            <button
              type="button"
              onClick={() => {
                setEditingWorkout(null)
                setDraftWorkoutBlock('Mis entrenos')
                setPlanMode('library')
              }}
              aria-label="Volver a entrenamientos"
              title="Volver a entrenamientos"
            >
              <ArrowLeft size={17} />
            </button>
            <h2>
              {editingWorkout ? <Pencil size={17} /> : <Plus size={17} />}
              {editingWorkout ? 'Editar' : 'Crear'}
            </h2>
          </div>
          <label className="workout-name-field">
            Nombre
            <input
              value={draftWorkoutName}
              placeholder="Push fuerza"
              onChange={(event) => setDraftWorkoutName(event.target.value)}
            />
          </label>
          <label className="workout-name-field">
            Bloque
            <input
              value={draftWorkoutBlock}
              placeholder="Pierna"
              onChange={(event) => setDraftWorkoutBlock(event.target.value)}
            />
          </label>
          <div className="field-row">
            <label className="exercise-search-field">
              Ejercicio
              <input
                value={newExercise.name}
                placeholder="Hip thrust"
                autoComplete="off"
                onFocus={() => setExerciseSearchOpen(true)}
                onBlur={() => window.setTimeout(() => setExerciseSearchOpen(false), 120)}
                onChange={(event) => {
                  setExerciseSearchOpen(true)
                  setNewExercise((current) => ({ ...current, name: event.target.value }))
                }}
              />
              {exerciseSearchOpen && (exerciseSuggestions.length > 0 || customExerciseName) && (
                <div className="exercise-suggestion-list" role="listbox">
                  {customExerciseName && (
                    <button
                      className="custom-exercise-option"
                      type="button"
                      onPointerDown={(event) => {
                        event.preventDefault()
                        setExerciseSearchOpen(false)
                      }}
                    >
                      <strong>{customExerciseName}</strong>
                      <small>Usar escrito</small>
                    </button>
                  )}
                  {exerciseSuggestions.map((exercise) => (
                    <button
                      key={exercise.name}
                      type="button"
                      onPointerDown={(event) => {
                        event.preventDefault()
                        setNewExercise((current) => ({ ...current, name: exercise.name }))
                        setExerciseSearchOpen(false)
                      }}
                    >
                      <strong>{exercise.name}</strong>
                      <small>
                        {[exercise.primaryMuscle, exercise.equipment]
                          .filter(Boolean)
                          .join(' · ')}
                      </small>
                    </button>
                  ))}
                </div>
              )}
            </label>
          </div>
          <div className="quick-grid">
            <NumberControl
              label="Series"
              value={newExercise.sets}
              suffix=""
              step={1}
              onChange={(sets) => setNewExercise((current) => ({ ...current, sets: Math.max(1, sets) }))}
            />
            <NumberControl
              label="Reps"
              value={newExercise.reps}
              suffix=""
              step={1}
              onChange={(reps) => setNewExercise((current) => ({ ...current, reps: Math.max(1, reps) }))}
            />
            <NumberControl
              label="Peso"
              value={newExercise.weight}
              suffix="kg"
              step={2.5}
              onChange={(weight) => setNewExercise((current) => ({ ...current, weight }))}
            />
          </div>
          <button
            className="primary-button"
            type="button"
            onClick={() => {
              setExerciseSearchOpen(false)
              onAddExercise()
            }}
          >
            <Plus size={17} />
            Añadir ejercicio
          </button>
          <div className="draft-list editable" aria-label="Ejercicios del entrenamiento">
            {draftExercises.map((exercise, index) => (
              <article className="draft-row" key={exercise.id}>
                <span>{index + 1}</span>
                <div>
                  <strong>{exercise.name}</strong>
                  <div className="draft-metrics">
                    <NumberControl
                      label="Series"
                      value={exercise.sets}
                      suffix=""
                      step={1}
                      onChange={(sets) => updateDraftExercise(exercise.id, { sets })}
                    />
                    <NumberControl
                      label="Reps"
                      value={exercise.reps}
                      suffix=""
                      step={1}
                      onChange={(reps) => updateDraftExercise(exercise.id, { reps })}
                    />
                    <NumberControl
                      label="Peso"
                      value={exercise.weight}
                      suffix="kg"
                      step={2.5}
                      onChange={(weight) => updateDraftExercise(exercise.id, { weight })}
                    />
                  </div>
                </div>
                <button
                  type="button"
                  onClick={() => onRemoveExercise(exercise.id)}
                  aria-label={`Quitar ${exercise.name}`}
                  title={`Quitar ${exercise.name}`}
                >
                  <X size={16} />
                </button>
              </article>
            ))}
          </div>
          <button
            className="secondary-button create-workout-button"
            type="button"
            onClick={() => {
              onSaveWorkout(editingWorkout)
              if (draftExercises.length) {
                setEditingWorkout(null)
                setPlanMode('library')
              }
            }}
            disabled={!draftExercises.length}
          >
            <Save size={17} />
            {editingWorkout ? 'Guardar cambios' : 'Guardar entrenamiento'}
          </button>
        </section>
      </section>
    )
  }

  return (
    <section className="plan-view">
      <section className="plan-block">
        <div className="plan-panel-head">
          <h2>
            <Target size={17} />
            Entrenamientos
          </h2>
          <button
            type="button"
            onClick={() => {
              setPreviewWorkout(null)
              setDraftWorkoutBlock('Mis entrenos')
              setPlanMode('create')
            }}
          >
            <Plus size={17} />
            Crear entrenamiento
          </button>
        </div>
        <div className="workout-levels" aria-label="Entrenamientos">
          {workoutGroups.map((group) => (
            <section className="workout-level" key={group.id}>
              <div className="workout-level-head">
                <strong>{group.label}</strong>
                <span>{group.tag}</span>
              </div>
              {group.workouts.length ? (
                <div className="template-strip">
                  {group.workouts.map((template) => (
                    <button
                      key={template.libraryId}
                      className={`${template.removable ? 'removable' : ''} ${draggedWorkout?.id === template.libraryId && draggedWorkout.active ? 'dragging' : ''}`}
                      type="button"
                      onClick={() => selectWorkout(template)}
                      onPointerDown={(event) => startWorkoutDrag(event, template)}
                      onPointerMove={(event) => moveWorkoutDrag(event, template)}
                      onPointerUp={finishWorkoutDrag}
                      onPointerCancel={finishWorkoutDrag}
                    >
                      <Target size={16} />
                      <span>
                        <strong>{template.name}</strong>
                      </span>
                    </button>
                  ))}
                </div>
              ) : (
                <button
                  className="empty-workout-level"
                  type="button"
                  onClick={() => {
                    setPreviewWorkout(null)
                    setPlanMode('create')
                  }}
                >
                  <Plus size={16} />
                  Crear entrenamiento
                </button>
              )}
            </section>
          ))}
        </div>
        <div
          ref={trashRef}
          className={`workout-trash-zone ${draggedWorkout?.active ? 'visible' : ''} ${draggedWorkout?.overTrash ? 'ready' : ''}`}
          aria-hidden="true"
        >
          <Trash2 size={21} />
        </div>
        {draggedWorkout?.active &&
          createPortal(
            <div
              className="workout-drag-ghost"
              style={{
                left: draggedWorkout.clientX,
                top: draggedWorkout.clientY,
              }}
              aria-hidden="true"
            >
              <Target size={16} />
              <strong>{draggedWorkout.workout.name}</strong>
            </div>,
            document.body,
          )}
        {previewWorkout && (
          <section className="workout-preview" aria-label={`Vista previa de ${previewWorkout.name}`}>
            <div className="workout-preview-head">
              <strong>{previewWorkout.name}</strong>
              <button
                type="button"
                onClick={() => setPreviewWorkout(null)}
                aria-label="Cerrar vista previa"
                title="Cerrar vista previa"
              >
                <X size={16} />
              </button>
            </div>
            <div className="preview-exercise-list">
              {previewExercises.map((exercise, index) => (
                <article className="preview-exercise-row" key={`${exercise.id}-${index}`}>
                  <span>{index + 1}</span>
                  <div>
                    <strong>{exercise.name}</strong>
                    <small>{exercise.sets}x{exercise.reps} · {exercise.weight} kg</small>
                  </div>
                </article>
              ))}
            </div>
            <button className="primary-button" type="button" onClick={() => onApplyTemplate(previewWorkout)}>
              <Dumbbell size={17} />
              Cargar entreno
            </button>
            <button className="secondary-button" type="button" onClick={() => shareWorkout(previewWorkout)}>
              <Share2 size={17} />
              Compartir
            </button>
            <button className="secondary-button" type="button" onClick={() => editWorkout(previewWorkout)}>
              <Pencil size={17} />
              Editar
            </button>
            <button
              className="danger-button"
              type="button"
              onClick={() => {
                onDeleteWorkout(previewWorkout)
                setPreviewWorkout(null)
              }}
            >
              <Trash2 size={17} />
              Eliminar
            </button>
            {shareNotice && <span className="share-feedback">{shareNotice}</span>}
          </section>
        )}
      </section>

    </section>
  )
}

function AchievementsView({
  player,
  history,
}: {
  player: Player
  history: HistoryEntry[]
}) {
  const levelProgress = getLevelProgress(player.xp)
  const displayHistory = useMemo(() => [...history, ...getDemoAchievementHistory(history)], [history])
  const sessions = useMemo(() => {
    const grouped = new Map<string, HistoryEntry[]>()

    displayHistory.forEach((entry) => {
      const key = entry.sessionId ?? `legacy-${entry.completedAt.slice(0, 10)}`
      grouped.set(key, [...(grouped.get(key) ?? []), entry])
    })

    return Array.from(grouped.entries())
      .map(([id, entries]) => {
        const sorted = [...entries].sort(
          (first, second) =>
            new Date(first.completedAt).getTime() - new Date(second.completedAt).getTime(),
        )
        const lastEntry = sorted.at(-1) ?? sorted[0]
        const firstEntry = sorted[0]
        const doneEntries = sorted.filter((entry) => entry.status === 'done')
        const skippedEntries = sorted.filter((entry) => entry.status === 'skipped')
        const duration =
          Math.max(...sorted.map((entry) => entry.sessionElapsedSeconds ?? 0)) ||
          Math.max(
            1,
            Math.round(
              (new Date(lastEntry.completedAt).getTime() - new Date(firstEntry.completedAt).getTime()) /
                1000,
            ),
          )

        return {
          id,
          dateKey: lastEntry.completedAt.slice(0, 10),
          date: new Date(lastEntry.completedAt),
          workoutName: lastEntry.workoutName ?? lastEntry.day ?? 'Entreno',
          entries: sorted,
          done: doneEntries.length,
          skipped: skippedEntries.length,
          duration,
          xp: doneEntries.reduce((total, entry) => total + entry.xp, 0),
        }
      })
      .sort((first, second) => second.date.getTime() - first.date.getTime())
  }, [displayHistory])
  const [selectedSessionId, setSelectedSessionId] = useState<string | null>(null)
  const selectedSession =
    sessions.find((session) => session.id === selectedSessionId) ?? sessions[0] ?? null
  const [visibleMonth, setVisibleMonth] = useState(() => {
    const date = new Date()
    date.setDate(1)
    date.setHours(12, 0, 0, 0)
    return date
  })
  const sessionsByDate = useMemo(() => {
    const grouped = new Map<string, typeof sessions>()

    sessions.forEach((session) => {
      grouped.set(session.dateKey, [...(grouped.get(session.dateKey) ?? []), session])
    })

    return grouped
  }, [sessions])
  const selectedDateSessions = selectedSession ? sessionsByDate.get(selectedSession.dateKey) ?? [] : []
  const calendarDays = useMemo(() => {
    const firstDay = new Date(visibleMonth)
    firstDay.setDate(1)
    const monthOffset = (firstDay.getDay() + 6) % 7
    const gridStart = new Date(firstDay)
    gridStart.setDate(firstDay.getDate() - monthOffset)

    return Array.from({ length: 42 }).map((_, index) => {
      const date = new Date(gridStart)
      date.setHours(12, 0, 0, 0)
      date.setDate(gridStart.getDate() + index)
      const key = date.toISOString().slice(0, 10)
      const daySessions = sessionsByDate.get(key) ?? []
      const realIntensity = Math.min(4, daySessions.reduce((total, session) => total + session.done, 0))
      const today = new Date()
      today.setHours(23, 59, 59, 999)

      return {
        key,
        date,
        inMonth: date.getMonth() === visibleMonth.getMonth(),
        isFuture: date.getTime() > today.getTime(),
        sessions: daySessions,
        hasTraining: realIntensity > 0,
        intensity: realIntensity,
      }
    })
  }, [sessionsByDate, visibleMonth])
  const monthLabel = visibleMonth.toLocaleDateString('es-ES', {
    month: 'long',
    year: 'numeric',
  })
  const dayStreak = getDayStreak(displayHistory)

  return (
    <section className="progress-view">
      <div className="level-card">
        <div className="level-head">
          <div>
            <span>Nivel</span>
            <strong>{levelProgress.level}</strong>
          </div>
          <div className="flame-pill">
            <Flame size={17} />
            {dayStreak}d
          </div>
        </div>
        <div className="progress-track level-progress">
          <span style={{ width: `${levelProgress.progress}%` }} />
        </div>
        <div className="level-meta">
          <span>{levelProgress.earnedInLevel}/{levelProgress.neededInLevel} XP</span>
        </div>
      </div>


      <section className="calendar-panel" aria-label="Calendario de entrenos">
        <div className="calendar-head">
          <button
            type="button"
            onClick={() =>
              setVisibleMonth((current) => {
                const next = new Date(current)
                next.setMonth(current.getMonth() - 1)
                return next
              })
            }
            aria-label="Mes anterior"
            title="Mes anterior"
          >
            <ChevronLeft size={17} />
          </button>
          <strong>{monthLabel}</strong>
          <button
            type="button"
            onClick={() =>
              setVisibleMonth((current) => {
                const next = new Date(current)
                next.setMonth(current.getMonth() + 1)
                return next
              })
            }
            aria-label="Mes siguiente"
            title="Mes siguiente"
          >
            <ChevronRight size={17} />
          </button>
        </div>
        <div className="weekday-row" aria-hidden="true">
          {['L', 'M', 'X', 'J', 'V', 'S', 'D'].map((day) => (
            <span key={day}>{day}</span>
          ))}
        </div>
        <div className="calendar-grid">
          {calendarDays.map((day) => (
            <button
              key={day.key}
              className={`calendar-day intensity-${day.intensity} ${day.hasTraining ? 'trained' : ''} ${day.inMonth && !day.isFuture ? '' : 'outside'} ${
                selectedSession?.dateKey === day.key ? 'selected' : ''
              }`}
              type="button"
              onClick={() => {
                const session = day.sessions[0]
                if (session) {
                  setSelectedSessionId(session.id)
                }
              }}
              aria-label={day.date.toLocaleDateString('es-ES')}
            >
              <span>{day.date.getDate()}</span>
            </button>
          ))}
        </div>
      </section>

      {selectedSession && (
        <section className="session-detail-panel">
          <div className="session-detail-head">
            <div>
              <strong>{selectedSession.workoutName}</strong>
              <span>{selectedSession.date.toLocaleDateString('es-ES')}</span>
            </div>
            <b>{formatElapsed(selectedSession.duration)}</b>
          </div>
          {selectedDateSessions.length > 1 && (
            <div className="session-switcher" aria-label="Entrenos del día">
              {selectedDateSessions.map((session) => (
                <button
                  key={session.id}
                  className={session.id === selectedSession.id ? 'active' : ''}
                  type="button"
                  onClick={() => setSelectedSessionId(session.id)}
                >
                  {session.workoutName}
                </button>
              ))}
            </div>
          )}
          <div className="session-metrics">
            <span className="metric-done">Hechas {selectedSession.done}</span>
            <span className="metric-skipped">No hechas {selectedSession.skipped}</span>
          </div>
          <div className="session-set-list">
            {selectedSession.entries.slice(-8).map((entry) => (
              <article key={entry.id} className="session-set-row">
                <span className={`status-dot ${entry.status}`} />
                <div>
                  <strong>{entry.exerciseName}</strong>
                  <small>
                    Serie {entry.setIndex ?? 1}/{entry.totalSetsInExercise ?? entry.sets} · {formatTimer(entry.setDurationSeconds ?? 0)} · descanso {formatTimer(entry.restBeforeSeconds ?? 0)}
                  </small>
                </div>
              </article>
            ))}
          </div>
        </section>
      )}
    </section>
  )
}


function RankingView({ history, profile }: { history: HistoryEntry[]; profile: Profile }) {
  const gymScore = useMemo(() => calculateGymScore(history), [history])
  const [rankingScope, setRankingScope] = useState<RankingScope>('city')
  const rankingRows = useMemo(() => getRankingRows(gymScore, rankingScope), [gymScore, rankingScope])
  const [userPoint, setUserPoint] = useState<MapPoint>(fallbackMapPoint)
  const [mapCenterOverride, setMapCenterOverride] = useState<MapPoint | null>(null)
  const [locationStatus, setLocationStatus] = useState('Ubicación aproximada')
  const mapDragRef = useRef<{ x: number; y: number; center: MapPoint } | null>(null)
  const visibleUsers = useMemo(() => getVisibleMapUsers(rankingScope), [rankingScope])
  const mapViewport = useMemo(() => {
    const viewport = getMapViewport(rankingScope, userPoint)
    return mapCenterOverride ? { ...viewport, center: mapCenterOverride } : viewport
  }, [rankingScope, userPoint, mapCenterOverride])
  const mapTiles = useMemo(() => getMapTiles(mapViewport), [mapViewport])
  const mapClusters = useMemo(() => getMapClusters(visibleUsers, mapViewport, rankingScope), [visibleUsers, mapViewport, rankingScope])
  const userPosition = projectMapPoint(userPoint, mapViewport)
  useEffect(() => {
    if (!navigator.geolocation) {
      return
    }

    navigator.geolocation.getCurrentPosition(
      (position) => {
        setUserPoint({
          lat: position.coords.latitude,
          lng: position.coords.longitude,
        })
        setMapCenterOverride(null)
        setLocationStatus('Tu zona aproximada')
      },
      () => setLocationStatus('Madrid aproximado'),
      { enableHighAccuracy: false, maximumAge: 1000 * 60 * 10, timeout: 7000 },
    )
  }, [])

  function onMapPointerDown(event: PointerEvent<HTMLDivElement>) {
    mapDragRef.current = {
      x: event.clientX,
      y: event.clientY,
      center: mapViewport.center,
    }
    event.currentTarget.setPointerCapture(event.pointerId)
  }

  function onMapPointerMove(event: PointerEvent<HTMLDivElement>) {
    if (!mapDragRef.current) {
      return
    }

    const start = mapDragRef.current
    const centerPixel = pointToWorldPixel(start.center, mapViewport.zoom)
    const nextCenterPixel = {
      x: centerPixel.x - (event.clientX - start.x),
      y: centerPixel.y - (event.clientY - start.y),
    }
    setMapCenterOverride(worldPixelToPoint(nextCenterPixel, mapViewport.zoom))
  }

  function onMapPointerUp() {
    mapDragRef.current = null
  }

  function locateUser() {
    if (!navigator.geolocation) {
      setLocationStatus('Ubicación no disponible')
      return
    }

    setLocationStatus('Buscando ubicación')
    navigator.geolocation.getCurrentPosition(
      (position) => {
        setUserPoint({
          lat: position.coords.latitude,
          lng: position.coords.longitude,
        })
        setMapCenterOverride(null)
        setLocationStatus('Tu zona aproximada')
      },
      () => setLocationStatus('Madrid aproximado'),
      { enableHighAccuracy: false, maximumAge: 1000 * 60 * 10, timeout: 7000 },
    )
  }

  return (
    <section className="ranking-view">
      <section className="gym-score-card" aria-label="Gym Score">
        <div className="gym-score-head">
          <div>
            <span>Gym Score</span>
            <strong>{gymScore.total}</strong>
          </div>
          <b>{gymScore.reliability}% fiable</b>
        </div>
        <div className="score-breakdown">
          <ScoreBar label="Fuerza" value={gymScore.strength} />
          <ScoreBar label="Constancia" value={gymScore.consistency} />
          <ScoreBar label="Volumen" value={gymScore.volume} />
          <ScoreBar label="Progreso" value={gymScore.progression} />
          <ScoreBar label="Variedad" value={gymScore.variety} />
          <ScoreBar label="Calidad" value={gymScore.quality} />
        </div>
      </section>

      <section className="ranking-card" aria-label="Ranking">
        <div className="ranking-head">
          <strong>Ranking</strong>
          <span>{getScopeLabel(rankingScope)}</span>
        </div>
        <div className="ranking-scopes">
          {([
            ['global', <Globe2 size={15} />],
            ['country', <MapPin size={15} />],
            ['city', <Users size={15} />],
            ['zone', <Target size={15} />],
          ] as const).map(([scope, icon]) => (
            <button
              key={scope}
              className={rankingScope === scope ? 'active' : ''}
              type="button"
              onClick={() => setRankingScope(scope)}
              aria-label={getScopeLabel(scope)}
              title={getScopeLabel(scope)}
            >
              {icon}
            </button>
          ))}
        </div>
        <div className="ranking-list">
          {rankingRows.map((row, index) => (
            <article className={row.isYou ? 'you' : ''} key={row.name}>
              <span>{index + 1}</span>
              <span className="ranking-avatar">
                {row.isYou && profile.photo ? <img src={profile.photo} alt="" style={{ objectPosition: `${profile.photoX}% ${profile.photoY}%` }} /> : <UserRound size={15} />}
              </span>
              <strong>{row.name}</strong>
              <b>{row.score}</b>
              <em>{row.isYou ? getCountryFlag(profile.country) : '🇪🇸'}</em>
            </article>
          ))}
        </div>
      </section>

      <section className="map-panel simple-map-panel" aria-label="Mapa de usuarios">
        <div className="map-panel-head">
          <div>
            <strong>Mapa</strong>
            <span>{getMapScopeCopy(rankingScope)}</span>
          </div>
          <button className="locate-button" type="button" onClick={locateUser}>
            <MapPin size={15} />
            Ubicarme
          </button>
        </div>

        <div
          className="world-map"
          aria-label="Mapa real con usuarios aproximados"
          onPointerDown={onMapPointerDown}
          onPointerMove={onMapPointerMove}
          onPointerUp={onMapPointerUp}
          onPointerCancel={onMapPointerUp}
        >
          <div className="map-tile-layer" aria-hidden="true">
            {mapTiles.map((tile) => (
              <img
                key={tile.id}
                className="map-tile"
                src={tile.src}
                alt=""
                loading="eager"
                draggable={false}
                style={{ left: `${tile.left}px`, top: `${tile.top}px` }}
              />
            ))}
          </div>
          <span
            className="map-user-pin me"
            style={{ left: `${userPosition.x}px`, top: `${userPosition.y}px` }}
            title={locationStatus}
          >
            Tú
          </span>
          {mapClusters.map((cluster) => (
            <button
              key={`${cluster.id}-${cluster.count}`}
              className={`map-user-pin ${cluster.count > 1 ? 'cluster' : ''}`}
              style={{ left: `${cluster.x}px`, top: `${cluster.y}px` }}
              type="button"
              title={cluster.users.map((user) => user.area).join(' · ')}
              aria-label={`${cluster.count} usuarios aproximados`}
            >
              {cluster.count > 1 ? cluster.count : ''}
            </button>
          ))}
          <a
            className="map-attribution"
            href="https://www.openstreetmap.org/copyright"
            target="_blank"
            rel="noreferrer"
          >
            © OpenStreetMap
          </a>
        </div>

        <div className="map-summary-row">
          <span>{locationStatus}</span>
          <strong>{visibleUsers.length} usuarios</strong>
        </div>
      </section>

    </section>
  )
}



function PartnerView({ profile }: { profile: Profile }) {
  const [trainingPlans, setTrainingPlans] = useState<TrainingPlanCard[]>(loadTrainingPlans)
  const [showPlanCreator, setShowPlanCreator] = useState(false)
  const [planDraft, setPlanDraft] = useState<TrainingPlanDraft>(defaultTrainingPlanDraft)
  const [activeChatPlan, setActiveChatPlan] = useState<TrainingPlanCard | null>(null)
  const [chatDraft, setChatDraft] = useState('')

  useEffect(() => {
    localStorage.setItem(trainingPlansStorageKey, JSON.stringify(trainingPlans))
  }, [trainingPlans])

  function saveTrainingPlan() {
    const nextPlan = createTrainingPlan(planDraft, profile)
    setTrainingPlans((current) => [nextPlan, ...current].slice(0, 8))
    setPlanDraft(defaultTrainingPlanDraft)
    setShowPlanCreator(false)
  }

  return (
    <section className="partner-view">
      <section className="training-plans-panel" aria-label="Planes de entreno">
        <div className="training-plans-head">
          <div>
            <strong>Planes de entreno</strong>
            <span>{trainingPlans.length} activos</span>
          </div>
          <button type="button" onClick={() => setShowPlanCreator((current) => !current)}>
            <Users size={15} />
            Buscar compañero
          </button>
        </div>

        {showPlanCreator && (
          <section className="training-plan-form" aria-label="Crear plan de entreno">
            <PlanChoiceGroup
              label="Cuándo"
              value={planDraft.when}
              options={planWhenOptions}
              onChange={(when) => setPlanDraft((current) => ({ ...current, when }))}
            />
            {planDraft.when === 'Fecha concreta' && (
              <label className="plan-date-field">
                <span>Fecha</span>
                <input
                  type="date"
                  value={planDraft.date}
                  onChange={(event) => setPlanDraft((current) => ({ ...current, date: event.target.value }))}
                />
              </label>
            )}
            <PlanMultiChoiceGroup
              label="Dónde"
              value={planDraft.where}
              options={planWhereOptions}
              onChange={(where) => setPlanDraft((current) => ({ ...current, where }))}
            />
            <PlanChoiceGroup
              label="Qué"
              value={planDraft.workout}
              options={planWorkoutOptions}
              onChange={(workout) => setPlanDraft((current) => ({ ...current, workout }))}
            />
            <PlanChoiceGroup
              label="Nivel"
              value={planDraft.level}
              options={planLevelOptions}
              onChange={(level) => setPlanDraft((current) => ({ ...current, level }))}
            />
            <PlanChoiceGroup
              label="Plazas"
              value={planDraft.spots}
              options={planSpotOptions}
              onChange={(spots) => setPlanDraft((current) => ({ ...current, spots }))}
            />
            <button className="primary-button" type="button" onClick={saveTrainingPlan}>
              <Plus size={17} />
              Crear plan
            </button>
          </section>
        )}

        <div className="training-plan-list">
          {trainingPlans.map((plan) => (
            <article className="training-plan-card" key={plan.id}>
              <div className="plan-card-main">
                <strong>{plan.title}</strong>
                <span>{plan.when}</span>
              </div>
              <div className="plan-card-place">
                <MapPin size={15} />
                <span>{plan.place}</span>
              </div>
              <div className="plan-card-tags">
                <span>{plan.level}</span>
                <span>{plan.spots}</span>
                <span>{plan.intensity}</span>
                <span>{plan.objective}</span>
              </div>
              <button className="accept-plan-button" type="button" onClick={() => setActiveChatPlan(plan)}>
                Aceptar plan
              </button>
            </article>
          ))}
        </div>
      </section>

      {activeChatPlan && (
        <section className="partner-chat-panel" aria-label="Chat de partner">
          <div className="partner-chat-head">
            <div>
              <strong>{activeChatPlan.title}</strong>
              <span>{activeChatPlan.place}</span>
            </div>
            <button type="button" onClick={() => setActiveChatPlan(null)} aria-label="Cerrar chat">
              <X size={15} />
            </button>
          </div>
          <div className="partner-chat-body">
            <p>Plan aceptado. Empieza el chat para coordinar.</p>
            <p className="mine">Me interesa entrenar contigo.</p>
          </div>
          <form
            className="partner-chat-form"
            onSubmit={(event) => {
              event.preventDefault()
              setChatDraft('')
            }}
          >
            <input value={chatDraft} onChange={(event) => setChatDraft(event.target.value)} placeholder="Escribe un mensaje" />
            <button type="submit">Enviar</button>
          </form>
        </section>
      )}
    </section>
  )
}

function PlanMultiChoiceGroup({
  label,
  value,
  options,
  onChange,
}: {
  label: string
  value: string[]
  options: string[]
  onChange: (value: string[]) => void
}) {
  function toggle(option: string) {
    const next = value.includes(option)
      ? value.filter((item) => item !== option)
      : [...value, option]
    onChange(next.length ? next : [option])
  }

  return (
    <section className="plan-choice-group">
      <span>{label}</span>
      <div>
        {options.map((option) => (
          <button
            key={option}
            className={value.includes(option) ? 'active' : ''}
            type="button"
            onClick={() => toggle(option)}
          >
            {option}
          </button>
        ))}
      </div>
    </section>
  )
}

function PlanChoiceGroup({
  label,
  value,
  options,
  onChange,
}: {
  label: string
  value: string
  options: string[]
  onChange: (value: string) => void
}) {
  return (
    <section className="plan-choice-group">
      <span>{label}</span>
      <div>
        {options.map((option) => (
          <button
            key={option}
            className={value === option ? 'active' : ''}
            type="button"
            onClick={() => onChange(option)}
          >
            {option}
          </button>
        ))}
      </div>
    </section>
  )
}

function ProfileView({
  player,
  profile,
  history,
  onPhotoChange,
  onProfileChange,
}: {
  player: Player
  profile: Profile
  history: HistoryEntry[]
  onPhotoChange: (file: File | null) => void
  onProfileChange: (patch: Partial<Profile>) => void
}) {
  const levelProgress = getLevelProgress(player.xp)

  return (
    <section className="profile-view">
      <label className="profile-photo-card">
        <input
          type="file"
          accept="image/*"
          onChange={(event) => onPhotoChange(event.target.files?.[0] ?? null)}
        />
        <span className={`profile-avatar ${profile.photo ? 'has-photo' : ''}`}>
          {profile.photo ? <img src={profile.photo} alt="" style={{ objectPosition: `${profile.photoX}% ${profile.photoY}%` }} /> : <span className="egg-avatar" />}
          <b><Camera size={18} /></b>
        </span>
        <strong>Perfil</strong>
      </label>

      {profile.photo && (
        <section className="profile-crop-card" aria-label="Encuadre de foto">
          <label>
            <span>Horizontal</span>
            <input
              type="range"
              min="0"
              max="100"
              value={profile.photoX}
              onChange={(event) => onProfileChange({ photoX: Number(event.target.value) })}
            />
          </label>
          <label>
            <span>Vertical</span>
            <input
              type="range"
              min="0"
              max="100"
              value={profile.photoY}
              onChange={(event) => onProfileChange({ photoY: Number(event.target.value) })}
            />
          </label>
        </section>
      )}

      <section className="profile-fields-card" aria-label="Datos básicos">
        <label>
          <span>Sexo</span>
          <select value={profile.sex} onChange={(event) => onProfileChange({ sex: event.target.value })}>
            <option value="">Sin definir</option>
            <option value="Mujer">Mujer</option>
            <option value="Hombre">Hombre</option>
            <option value="Otro">Otro</option>
          </select>
        </label>
        <label>
          <span>Edad</span>
          <input inputMode="numeric" value={profile.age} onChange={(event) => onProfileChange({ age: event.target.value.replace(/\D/g, '').slice(0, 2) })} />
        </label>
        <label>
          <span>País</span>
          <input value={profile.country} onChange={(event) => onProfileChange({ country: event.target.value })} />
        </label>
        <label>
          <span>Ciudad</span>
          <input value={profile.city} onChange={(event) => onProfileChange({ city: event.target.value })} />
        </label>
        <label className="full">
          <span>Gimnasio</span>
          <input value={profile.gym} onChange={(event) => onProfileChange({ gym: event.target.value })} />
        </label>
      </section>

      <section className="profile-level-card">
        <span>Nivel {levelProgress.level}</span>
        <div className="progress-track level-progress">
          <span style={{ width: `${levelProgress.progress}%` }} />
        </div>
        <strong>{player.xp.toLocaleString('es-ES')} XP</strong>
      </section>

      <AchievementsView player={player} history={history} />
    </section>
  )
}

function GymBuddy({ mood, compact = false }: { mood: MascotMood; compact?: boolean }) {
  return (
    <div className={`gym-buddy ${mood} ${compact ? 'compact' : ''}`} aria-hidden="true">
      <div className="buddy-shadow" />
      <div className="buddy-body">
        <span className="buddy-horn left" />
        <span className="buddy-horn right" />
        <span className="buddy-arm left" />
        <span className="buddy-arm right" />
        <span className="buddy-bar" />
        <span className="buddy-plate left" />
        <span className="buddy-plate right" />
        <span className="buddy-eye left" />
        <span className="buddy-eye right" />
        <span className="buddy-brow left" />
        <span className="buddy-brow right" />
        <span className="buddy-mouth" />
        <span className="buddy-band" />
      </div>
    </div>
  )
}

function CelebrationToast({ celebration }: { celebration: Celebration | null }) {
  if (!celebration) {
    return null
  }

  return (
    <div key={celebration.id} className={`celebration-toast ${celebration.type}`} role="status">
      <div className="burst" aria-hidden="true">
        {Array.from({ length: 14 }).map((_, index) => (
          <span key={index} />
        ))}
      </div>
      <div className="reward-rain" aria-hidden="true">
        {Array.from({ length: 8 }).map((_, index) => (
          <i key={index} />
        ))}
      </div>
      <strong>{celebration.type === 'pr' ? 'PR' : celebration.type === 'done' ? '+XP' : 'X'}</strong>
      <span>{celebration.value ?? celebration.message}</span>
    </div>
  )
}

function TabButton({
  active,
  icon,
  label,
  onClick,
}: {
  active: boolean
  icon: React.ReactNode
  label: string
  onClick: () => void
}) {
  return (
    <button className={active ? 'active' : ''} type="button" onClick={onClick}>
      {icon}
      {label}
    </button>
  )
}

function ScoreBar({ label, value }: { label: string; value: number }) {
  return (
    <div className="score-bar">
      <span>{label}</span>
      <div>
        <i style={{ width: `${value}%` }} />
      </div>
      <b>{value}</b>
    </div>
  )
}

function NumberControl({
  label,
  value,
  suffix,
  step,
  onChange,
}: {
  label: string
  value: number
  suffix: string
  step: number
  onChange: (value: number) => void
}) {
  const decimals = step < 1 ? 1 : Number.isInteger(step) ? 0 : 1

  return (
    <div className="number-control" onPointerDown={(event) => event.stopPropagation()}>
      <span>{label}</span>
      <div className="number-stepper">
        <button
          type="button"
          onClick={() => onChange(Number(Math.max(0, value - step).toFixed(decimals)))}
          aria-label={`Bajar ${label}`}
          title={`Bajar ${label}`}
        >
          <Minus size={15} />
        </button>
        <label className="number-value">
          <input
            type="number"
            inputMode="decimal"
            min="0"
            step={step}
            value={value}
            aria-label={label}
            onChange={(event) => {
              if (!event.target.value) {
                return
              }

              const parsed = Number(event.target.value)
              if (Number.isFinite(parsed)) {
                onChange(Math.max(0, Number(parsed.toFixed(decimals))))
              }
            }}
          />
          {suffix && <small>{suffix}</small>}
        </label>
        <button
          type="button"
          onClick={() => onChange(Number((value + step).toFixed(decimals)))}
          aria-label={`Subir ${label}`}
          title={`Subir ${label}`}
        >
          <Plus size={15} />
        </button>
      </div>
    </div>
  )
}

export default App
