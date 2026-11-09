import { onMounted, onUnmounted, ref } from 'vue'
import { peerOptions, type ServerMsg } from '@couch/shared'
import { openRoom, type Room, type RoomHandlers } from '../room/host'

/** Opens the party room on mount and closes it on unmount. One try: a failure shows "Can't create room". */
export function useRoom(handlers: RoomHandlers) {
  const code = ref('')
  const failed = ref(false)
  let room: Room | null = null

  onMounted(async () => {
    try {
      room = await openRoom(handlers, peerOptions(import.meta.env))
      code.value = room.code
    } catch {
      failed.value = true
    }
  })
  onUnmounted(() => room?.close())

  return { code, failed, send: (id: string, msg: ServerMsg) => room?.send(id, msg) }
}
