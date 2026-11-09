import { ref, watch, type Ref } from 'vue'
import QRCode from 'qrcode'
import { controllerUrl } from '@couch/shared'

/** The controller URL for a room code and its QR image. */
export function useJoinLink(code: Ref<string>) {
  const url = ref('')
  const qr = ref('')
  watch(
    code,
    async (c) => {
      url.value = controllerUrl(location.origin + import.meta.env.BASE_URL + 'controller/', c)
      qr.value = await QRCode.toDataURL(url.value)
    },
    { immediate: true },
  )
  return { url, qr }
}
