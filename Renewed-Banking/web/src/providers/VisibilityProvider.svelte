<script lang="ts">
  import { fetchNui } from '../utils/fetchNui';
  import { onMount } from 'svelte';
  import {
    visibility,
    accounts,
    activeAccount,
    loading,
    notify,
    popupDetails,
    atm,
    translations,
  } from '../store/stores';
  import { useNuiEvent } from '../utils/useNuiEvent';
  import { isEnvBrowser } from '../utils/misc';
  let isVisible: boolean;

  visibility.subscribe((visible) => {
    isVisible = visible;
  });

  useNuiEvent<any>('setVisible', (data) => {
    accounts.set(isEnvBrowser() ? data.data.accounts : data.accounts);
    activeAccount.update(() => (isEnvBrowser() ? data.data.accounts[0].id : data.accounts[0].id));
    visibility.set(isEnvBrowser() ? data.data.status : data.status);
    loading.set(isEnvBrowser() ? data.data.loading : data.loading);
    atm.set(isEnvBrowser() ? data.data.atm : data.atm);
  });

  useNuiEvent<any>('setLoading', (data) => {
    loading.set(data.status);
  });

  useNuiEvent<any>('notify', (data) => {
    notify.set(data.status);
    setTimeout(() => {
      notify.set('');
    }, 3500);
  });

  useNuiEvent<any>('updateLocale', (data) => {
    translations.set(data.translations);
  });

  onMount(() => {
    const keyHandler = (e: KeyboardEvent) => {
      if (isVisible && ['Escape'].includes(e.code)) {
        fetchNui('closeInterface');
        visibility.set(false);
        popupDetails.update((val) => ({
          ...val,
          actionType: '',
        }));
      }
    };

    window.addEventListener('keydown', keyHandler);
    return () => window.removeEventListener('keydown', keyHandler);
  });
</script>

{#if isVisible}
  <slot />
{/if}
