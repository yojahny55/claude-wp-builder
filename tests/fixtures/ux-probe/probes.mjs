// Site probes for the ux-probe fixture: one that works, one whose selector never matches.
export default [
  {
    id: 'account-popup',
    criterion: 'UX-012',
    viewports: ['desktop'],
    run: async ({ page }) => {
      await page.click('#open', { timeout: 2000 });
      return { opened: await page.evaluate(() => !!document.querySelector('#popup.open') || document.body.dataset.open === '1') };
    },
  },
  {
    id: 'guessed-selector',
    criterion: 'UX-013',
    viewports: ['desktop'],
    run: async ({ page }) => {
      await page.click('.bwp-component-account-i', { timeout: 500 });
      return true;
    },
  },
];
