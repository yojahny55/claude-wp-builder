// Site probes for the ux-probe fixture: one that navigates away and succeeds, one that
// works, one whose selector never matches.
export default [
  {
    id: 'wanders',
    criterion: 'UX-010',
    viewports: ['desktop'],
    run: async ({ page, url }) => {
      await page.goto(new URL('/second/', url).href);
      return true;
    },
  },
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
