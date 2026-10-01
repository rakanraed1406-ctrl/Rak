<script lang="ts">
  import VisibilityProvider from "./providers/VisibilityProvider.svelte";
  import { debugData } from "./utils/debugData";
  import AccountsContainer from "./components/AccountsContainer.svelte";
  import Popup from "./components/Popup.svelte";
  import Loading from "./components/Loading.svelte";
  import Notification from "./components/Notification.svelte";
  import { popupDetails, loading, notify } from "./store/stores";

  debugData([
    {
      action: "setVisible",
      data: {
        accounts: [
          {
            id: 'FFFFF08',
            name: "Qwade Bot",
            amount: 120000,
            cash: 10000,
            transactions: [
              {
                trans_id: 0,
                title: "Meth Dealing",
                trans_type: "withdraw",
                receiver: "qwade",
                amount: 1000,
                time: "12:30",
                issuer: "bank",
                message: "Im a fiend",
              },
              {
                trans_id: 1,
                title: "Meth Dealing",
                trans_type: "deposit",
                receiver: "qwade",
                amount: 1000,
                time: "12:30",
                issuer: "bank",
                message: "Im a fiend",
              },
              {
                trans_id: 2,
                title: "Dog Sitting",
                trans_type: "deposit",
                receiver: "qwade",
                amount: 150,
                time: "12:30",
                issuer: "bank",
                message: "doggos",
              },
              {
                trans_id: 3,
                title: "Dog Sitting",
                trans_type: "deposit",
                receiver: "qwade",
                amount: 150,
                time: "12:30",
                issuer: "bank",
                message: "doggos",
              },
              {
                trans_id: 4,
                title: "Dog Sitting",
                trans_type: "deposit",
                receiver: "qwade",
                amount: 150,
                time: "12:30",
                issuer: "bank",
                message: "doggos",
              }
            ],
            type: "Personal",
            isFrozen: false,
          },
          {
            id: 'FFFdFSD',
            name: "Law Enforcement",
            amount: 1000,
            cash: 10000,
            transactions: [
              {
                trans_id: 0,
                title: "Meth Dealing 2",
                trans_type: "withdraw",
                receiver: "qwadebot",
                amount: 1000,
                time: "12:30",
                issuer: "bank",
                message: "Im a fiend 2",
              },
            ],
            type: "Business",
            isFrozen: false,
          },
          {
            id: 'FFsFFSD',
            name: "Law Enforcement",
            amount: 1000,
            cash: 10000,
            transactions: [
              {
                trans_id: 0,
                title: "Meth Dealing 2",
                trans_type: "withdraw",
                receiver: "qwadebot",
                amount: 1000,
                time: "12:30",
                issuer: "bank",
                message: "Im a fiend 2",
              },
            ],
            type: "Business",
            isFrozen: false,
          },
          {
            id: 'FFsFddFSD',
            name: "Law Enforcement",
            amount: 1000,
            cash: 10000,
            transactions: [
              {
                trans_id: 0,
                title: "Meth Dealing 2",
                trans_type: "withdraw",
                receiver: "qwadebot",
                amount: 1000,
                time: "12:30",
                issuer: "bank",
                message: "Im a fiend 2",
              },
            ],
            type: "Business",
            isFrozen: false,
          },
          {
            id: 'FFFaFSD',
            name: "Law Enforcement",
            amount: 1000,
            cash: 10000,
            transactions: [
              {
                trans_id: 0,
                title: "Meth Dealing 2",
                trans_type: "withdraw",
                receiver: "qwadebot",
                amount: 1000,
                time: "12:30",
                issuer: "bank",
                message: "Im a fiend 2",
              },
            ],
            type: "Business",
            isFrozen: false,
          },
        ],
        status: true,
        loading: false,
        atm: false,
      },
    },
  ]);
</script>

<svelte:head>
  <link
    rel="stylesheet"
    href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.1.2/css/all.min.css"
    integrity="sha512-1sCRPdkRXhBV2PBLUdRb4tMg1w2YPf37qatUFeS7zlBy7jJI8Lf4VHwWfZZfpXtYSLy85pkm9GaYVYMfw5BC1A=="
    crossorigin="anonymous"
    referrerpolicy="no-referrer"
  />
</svelte:head>

<VisibilityProvider>
  <AccountsContainer />
  {#if $popupDetails.actionType !== ""}
    <Popup />
  {/if}
  {#if $notify !== ""}
    <Notification />
  {/if}
</VisibilityProvider>
{#if $loading}
  <Loading />
{/if}
