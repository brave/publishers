import * as React from "react";
import { FormattedMessage, injectIntl } from "react-intl";
import routes from "../../routes";
import { FlexWrapper } from "../../style";
import BitflyerIcon from "./bitflyerConnection/BitflyerIcon";
import GeminiIcon from "./geminiConnection/GeminiIcon";
import UpholdIcon from "./upholdConnection/UpholdIcon";

// This shows the Connect Buttons for the different Wallet Providers
const NotConnected = (props) => (
  <div className="row">
    <div className="col-6">
      <h6>
        <FormattedMessage id="walletServices.brave.title" />
      </h6>
      <FormattedMessage id="walletServices.brave.description" />
    </div>
    <div className="col-6 d-flex flex-column justify-content-center align-items-end">
      {props.featureFlags.gemini_enabled && props.locale !== 'ja' && <GeminiConnectButton />}
      {props.locale !== 'ja' && <UpholdConnectButton />}
      {props.featureFlags.bitflyer_enabled && props.locale === 'ja' && <BitflyerConnectButton />}
    </div>
  </div>
);

// This button connects to the uphold resource on the Publishers backend.
// The data-method is a built-in Rails method that will use rails-ujs to submit a "patch" request to the backend
// The backend updates the state token and then redirects to Uphold to have the user fill out their login details.
// Afterwards this redirects the user to the UpholdController/#create action.
const UpholdConnectButton = () => (
  <a
    className="btn btn-secondary font-weight-bold mb-2"
    data-piwik-action="UpholdConnectClicked"
    data-piwik-name="Clicked"
    data-piwik-value="Dashboard"
    rel="nofollow"
    data-method="post"
    href={routes.publishers.uphold.connect}
  >
    <FlexWrapper className="align-items-center">
      <FormattedMessage id="walletServices.uphold.connect" />
      <UpholdIcon />
    </FlexWrapper>
  </a>
);

const GeminiConnectButton = () => (
  <a
    className="btn btn-secondary font-weight-bold mb-2"
    data-piwik-action="GeminiConnectClicked"
    data-piwik-name="Clicked"
    data-piwik-value="Dashboard"
    rel="nofollow"
    data-method="post"
    href={routes.publishers.gemini.connect}
  >
    <FlexWrapper className="align-items-center">
      <FormattedMessage id="walletServices.gemini.connect" />
      <GeminiIcon />
    </FlexWrapper>
  </a>
);

const BitflyerConnectButton = () => (
  <a
    className="btn btn-secondary font-weight-bold mb-2"
    data-piwik-action="BitflyerConnectClicked"
    data-piwik-name="Clicked"
    data-piwik-value="Dashboard"
    rel="nofollow"
    data-method="post"
    href={routes.publishers.bitflyer.connect}
  >
    <FlexWrapper className="align-items-center">
      <FormattedMessage id="walletServices.bitflyer.connect" />
      <BitflyerIcon />
    </FlexWrapper>
  </a>
);

export default injectIntl(NotConnected);
