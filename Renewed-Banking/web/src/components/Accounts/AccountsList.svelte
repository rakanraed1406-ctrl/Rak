<script lang="ts">
  import { accounts } from '../../store/stores';
  import AccountListItem from './AccountListItem.svelte';

  let accSearch = '';
</script>

<aside>
  <input type="text" class="acc-search" placeholder="Account Search..." bind:value={accSearch} />
  <section class="scroller">
    {#if $accounts.filter((item) => item.name.toLowerCase().includes(accSearch.toLowerCase())).length > 0}
      {#each $accounts.filter((item) => item.name
          .toLowerCase()
          .includes(accSearch.toLowerCase())) as account (account.id)}
        <AccountListItem {account} />
      {/each}
    {:else}
      <h3 style="text-align: left; color: #F3F4F5; margin-top: 1rem;">No accounts found</h3>
    {/if}
  </section>
</aside>

<style>
  aside {
    flex: 0 0 25%;
    padding-left: 1rem;
    padding-top: 0.4rem;
  }
  .acc-search {
    width: 100%;
    border-radius: 5px;
    border: none;
    padding: 1.4rem;
    margin-bottom: 1rem;
    background-color: var(--clr-primary-light);
    color: #fff;
  }
</style>
