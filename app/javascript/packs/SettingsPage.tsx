import * as React from "react";
import * as ReactDOM from "react-dom";
import { FormattedMessage, IntlProvider, useIntl } from "react-intl";
import { submitForm } from "../utils/request";

import { LoaderIcon } from "brave-ui/components/icons";
import en, { flattenMessages } from "../locale/en";
import ja from "../locale/ja";

import routes from "../views/routes";

interface IContactFormState {
  isEditMode: boolean;
  email: string;
  name: string;
  pendingEmail: string;
}

// This react component is used on the promo panel for the homepage.
// This displays a listing of group, price, and confirmed count to the end user

class ContactForm extends React.Component<any, IContactFormState> {
  constructor(props) {
    super(props);

    this.state = {
      email: this.props.email,
      isEditMode: false,
      name: this.props.name,
      pendingEmail: this.props.pending_email || this.props.email
    };
  }

  public setEdit = () => {
    this.setState({ isEditMode: true });
  };

  public setName = (e) => {
    this.setState({ name: e.target.value });
  };

  public setPendingEmail = (e) => {
    this.setState({ pendingEmail: e.target.value });
  };

  public cancelEdit = () => {
    this.setState({ isEditMode: false });
  };

  public save = () => {
    this.setState({ isEditMode: false });
  };

  public render() {
    return (
      <React.Fragment>
        <div className="d-flex justify-content-between">
          <h5>
            <FormattedMessage id="settings.contact.heading" />
          </h5>
          <a href="#" onClick={this.setEdit}>
            <FormattedMessage id="settings.contact.edit" />
          </a>
        </div>

        {this.state.isEditMode && (
          <EditForm
            {...this.state}
            cancelEdit={this.cancelEdit}
            setPendingEmail={this.setPendingEmail}
            setName={this.setName}
            save={this.save}
          />
        )}

        {!this.state.isEditMode && (
          <div>
            <div>{this.state.name}</div>
            <div>{this.props.email}</div>

            {this.state.pendingEmail && this.state.pendingEmail !== this.props.email && (
              <div className="alert alert-warning mt-2">
                <FormattedMessage
                  id="settings.contact.pendingEmail"
                  values={{
                    email: this.state.pendingEmail
                  }}
                />
              </div>
            )}
          </div>
        )}
      </React.Fragment>
    );
  }
}


const EditForm = props => {
  const intl = useIntl();
  const [error, setError] = React.useState(null);
  const [isLoading, setLoading] = React.useState(false);

  const submit = async event => {
    setLoading(true);

    const data = new FormData();
    data.append("publisher[name]", props.name);
    data.append("publisher[pending_email]", props.pendingEmail);
    data.append("_method", "patch");

    await fetch(routes.publishers.update.path, {
      body: data,
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": document.head
          .querySelector("[name=csrf-token]")
          .getAttribute("content"),
        "X-Requested-With": "XMLHttpRequest"
      },
      method: "POST"
    }).then(response => {
      setLoading(false);

      if (response.status === 400) {
        setError(<FormattedMessage id="settings.contact.error" />);
        return;
      }

      response
        .json()
        .then(json => {
          props.save();
        })
        .catch(e => {
          setError(e.message);
        });
    });
  };

  return (
    <form className="in-place-edit" onSubmit={submit} id="update_contact">
      <div className="form-group">
        <label>
          <FormattedMessage id="settings.contact.name" />
        </label>
        <input
          value={props.name}
          onChange={props.setName}
          className="form-control"
        />
      </div>
      <div className="form-group">
        <label>
          <FormattedMessage id="settings.contact.email" />
        </label>
        <input
          type="email"
          value={props.pendingEmail}
          onChange={props.setPendingEmail}
          className="form-control"
        />
      </div>

      <div className="button form-group">
        <input
          type="submit"
          className="btn btn-primary"
          value={intl.formatMessage({ id: "shared.save" })}
        />
        <a href="#" onClick={props.cancelEdit} className="btn btn-link">
          <FormattedMessage id="shared.cancel" />
        </a>
        {isLoading && <LoaderIcon style={{ width: "48px" }} />}
      </div>
      {error && <div className="mt-4 alert alert-warning">{error}</div>}
    </form>
  );
};

document.addEventListener("DOMContentLoaded", () => {
  const element = document.getElementById("contact_section");
  const props = JSON.parse(element.dataset.props);

  const locale = document.body.dataset.locale;
  let localePackage: object = en;
  if (locale === "ja") {
    localePackage = ja;
  }
  ReactDOM.render(
    <IntlProvider locale={locale} messages={flattenMessages(localePackage)}>
      <ContactForm {...props} />
    </IntlProvider>,
    element
  );

  const publisherMarketingEmailCheckbox = document.getElementById("publisher_subscribed_to_marketing_emails");
  publisherMarketingEmailCheckbox.addEventListener(
    "click",
    event => {
      submitForm("update_publisher_marketing_email_form", "PATCH", true);
    },
    false
  );

  const sendEmailCheckBox = document.getElementById("send_emails");
  sendEmailCheckBox.addEventListener(
    "change",
    event => {
      submitForm("update_send_email_form", "PATCH", true);
      const snoozeDetails = document.getElementById("snoozeDetails");
      if (snoozeDetails) {
        snoozeDetails.remove();
      }
    },
    false
  );
});
