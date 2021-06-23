import * as React from "react";
import * as ReactDOM from "react-dom";

import { IntlProvider, FormattedMessage, useIntl } from "react-intl";
import en, { flattenMessages } from "../locale/en";
import ja from "../locale/ja";

import Modal, { ModalSize } from "../components/modal/Modal";

const Number = (props) => (
  <div className="d-flex py-3">
    <div
      className="text-primary border border-primary rounded-circle m-2 d-flex justify-content-center align-items-center"
      style={{
        minWidth: "50px",
        minHeight: "50px",
        maxHeight: "50px",
        maxWidth: "50px",
        fontSize: "1.25em",
        fontWeight: "600",
      }}
    >
      {props.number}
    </div>
    <div className="ml-3 text-left">
      <h6 className="text-primary font-weight-normal">{props.title}</h6>
      <p className="text-dark">{props.description}</p>
    </div>
  </div>
);

const WelcomeModal = (props) => {
  const [isOpen, setOpen] = React.useState(props.isOpen);
  const intl = useIntl();

  return (
    <Modal
      show={isOpen}
      size={ModalSize.ExtraSmall}
      handleClose={() => setOpen(false)}
    >
      <div className="text-center my-2">
        <h3 className="text-primary font-weight-normal">
          <FormattedMessage id="homepage.welcome.title" />
        </h3>
        <p className="my-3">
          <FormattedMessage id="homepage.welcome.description" />
        </p>

        <div className="container mb-3">
          <Number
            number={intl.formatMessage({ id: "homepage.welcome.first.number" })}
            title={intl.formatMessage({ id: "homepage.welcome.first.title" })}
            description={intl.formatMessage({
              id: "homepage.welcome.first.description",
            })}
          />

          <Number
            number={intl.formatMessage({
              id: "homepage.welcome.second.number",
            })}
            title={intl.formatMessage({ id: "homepage.welcome.second.title" })}
            description={intl.formatMessage({
              id: "homepage.welcome.second.description",
            })}
          />
        </div>

        <a className="w-100 btn btn-primary text-white" onClick={() => setOpen(false)}>
          <FormattedMessage id="shared.ok" />
        </a>
      </div>
    </Modal>
  );
};

document.addEventListener("DOMContentLoaded", () => {
  const container = document.getElementById("welcomeModal");
  const props = JSON.parse(container.dataset.props);
  let localePackage = en;
  if (document.body.dataset.locale === "ja") {
    localePackage = ja;
  }
  ReactDOM.render(
    <IntlProvider
      locale={document.body.dataset.locale}
      messages={flattenMessages(localePackage)}
    >
      <WelcomeModal {...props} />
    </IntlProvider>,

    container
  );
});
