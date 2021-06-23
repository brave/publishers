import * as moment from "moment";
import * as React from "react";
import * as ReactDOM from "react-dom";

import { FormattedMessage, injectIntl, IntlProvider } from "react-intl";
import en, { flattenMessages } from "../../locale/en";
import ja from "../../locale/ja";

import { LoaderIcon } from "brave-ui/components/icons";
import Information from "./Information";

import routes from "../../views/routes";

import ArrowPointer from "./referralPanel/ArrowPointer";
import Groups from "./referralPanel/Groups";
import ReferralStats from "./referralPanel/ReferralStats";

export enum ReferralType {
  FINALIZED  = "finalized",
  FIRST_RUNS = "first_runs",
  RETRIEVALS = "retrievals"
}

export interface IReferralCounts {
  finalized: number;
  first_runs: number;
  retrievals: number;
}

export interface IGroup{
  id: string;
  name: string;
  amount: string;
  currency: string;
  counts: IReferralCounts;
}

interface IReferralGroupsState {
  errorMessage: string;
  groups: IGroup[];
  isLoading: boolean;
  month: string;
  lastUpdated: string;
  selected: ReferralType;
  totals: IReferralCounts;
}

// This react component is used on the promo panel for the homepage.
// This displays a listing of group, price, and confirmed count to the end user

class ReferralPanel extends React.Component<any, IReferralGroupsState> {
  private cachedData = {};

  constructor(props) {
    super(props);

    this.state = {
      errorMessage: null,
      groups: [],
      isLoading: true,
      lastUpdated: null,
      month: moment()
        .locale("en")
        .format("MMMM YYYY"),
      selected: ReferralType.FINALIZED,
      totals: {
        finalized: 0,
        first_runs: 0,
        retrievals: 0
      }
    };
  }

  public componentDidMount = () => {
    this.loadGroups();
  };

  public setMonth = e => {
    this.setState({ month: e.target.value, isLoading: true }, this.loadGroups);
  };

  public changeSelected = (selected: ReferralType) => {
    this.setState({ selected });
  };

  public async loadGroups() {
    const cacheKey =
    this.props.intl.locale + this.state.month;

  if (this.cachedData[cacheKey]) {
    this.updateStateWithData(this.cachedData[cacheKey]);
    return;
  }

    await fetch(
      routes.publishers.promo_registrations.overview.path.replace(
        "{id}",
        this.props.publisherId
      ) + `&month=${this.state.month}&locale=${this.props.intl.locale}&kind=${this.state.selected}`,
      {
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": document.head
            .querySelector("[name=csrf-token]")
            .getAttribute("content"),
          "X-Requested-With": "XMLHttpRequest"
        },
        method: "GET"
      }
    ).then(response => {
      response
        .json()
        .then(json => {
          this.cachedData[cacheKey] = json
          this.updateStateWithData(this.cachedData[cacheKey])
        })
        .catch(() => {
          this.setState({
            errorMessage: this.props.intl.formatMessage({
              id: "common.unexpectedError"
            }),
            isLoading: false
          });
        });
    });
  }

  public updateStateWithData = (json) => {
    this.setState({
      groups: json.groups,
      isLoading: false,
      lastUpdated: json.lastUpdated,
      totals: json.totals
    });
  }

  public monthOptions = () => {
    const dateStart = moment("2019-10-01");
    const dateEnd = moment();
    const interim = dateStart.clone();
    const timeValues = [];

    while (dateEnd > interim || interim.format("M") === dateEnd.format("M")) {
      timeValues.push({
        key: interim.locale(this.props.intl.locale).format("MMMM YYYY"),
        value: interim.locale("en").format("MMMM YYYY")
      });
      interim.add(1, "month");
    }

    return timeValues;
  };

  public render() {
    const content = (
      <React.Fragment>
        <div className="d-flex align-items-center justify-content-between flex-wrap">
          <h1 className="promo-panel-title-item m-0 p-0">
            <FormattedMessage id="homepage.referral.title" />
          </h1>
          <div className="promo-period">
            <select onChange={this.setMonth} value={this.state.month}>
              {this.monthOptions().map(month => (
                <option key={month.value} value={month.value}>
                  {month.key}
                </option>
              ))}
            </select>
          </div>
        </div>

        <div className="py-2">
          <FormattedMessage id="homepage.referral.statement" />
        </div>

        {this.state.errorMessage && (
          <div className="h-100 font-weight-bold">
            <div>{this.state.errorMessage}</div>
            <div>
              <a
                href="#"
                onClick={() =>
                  this.setState({ isLoading: true }, this.loadGroups)
                }
              >
                Retry
              </a>
            </div>
          </div>
        )}

        {!this.state.errorMessage && (
          <React.Fragment>
            <div className="row m-0">
              <ReferralStats
                totals={this.state.totals}
                selected={this.state.selected}
                changeSelected={this.changeSelected}
              />

              <Groups groups={this.state.groups} selected={this.state.selected} />
            </div>

            <div className="row promo-info mb-2">
              <Information />
              <a href="https://support.brave.com/hc/en-us/articles/360025284131-What-do-the-referral-metrics-on-my-dashboard-mean-">
                <FormattedMessage id="homepage.referral.details" />
              </a>
            </div>

            <small
              style={{
                bottom: "0.5rem",
                color: "rgba(255,255,255, 0.7)",
                position: "absolute",
                right: "1.5rem"
              }}
            >
              {this.state.lastUpdated}
            </small>
          </React.Fragment>
        )}
      </React.Fragment>
    );

    return (
      <>
        {this.state.isLoading && (
          <LoaderIcon style={{ width: "36px", margin: "0 auto" }} />
        )}
        {!this.state.isLoading && content}
      </>
    );
  }
}

const ReferralPanelWrapped = injectIntl(ReferralPanel);

document.addEventListener("DOMContentLoaded", () => {
  const element = document.getElementById("react-promo-panel");
  const props = JSON.parse(element.dataset.props);
  const locale = document.body.dataset.locale;
  let localePackage: object = en;
  if (locale === "ja") {
    localePackage = ja;
  }
  moment.locale(locale);
  ReactDOM.render(
    <IntlProvider
      locale={document.body.dataset.locale}
      messages={flattenMessages(localePackage)}
    >
      <ReferralPanelWrapped {...props} />
    </IntlProvider>,
    element
  );
});
