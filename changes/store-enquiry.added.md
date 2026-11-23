- **A catalog store's product pages offer its enquiry channels.** A store that sells nothing
  online recorded `whatsapp` and `form` as enquiry channels, and nothing rendered them.
  `/wp-woo-setup` Step 6.5 now copies a fixed file into the theme that adds the WhatsApp
  number, its message and a Contact Form 7 form ID to the theme's settings page, and shows a
  WhatsApp link and the form on each product page while store-kit's catalog mode is on. Empty
  fields render nothing, so installing it changes no page until the client fills them; the
  plugin never fills the number itself.
