import React from "react";
import ReactDOM from "react-dom";
import {IntlProvider } from 'react-intl';
import { BrowserRouter as Router, Route, Switch } from "react-router-dom";
import { Home, SignUp, LogIn } from "./views";
import "./style/normalize-style.css";
import "./style/style.css";

import en from './locale/en';
import ja from './locale/ja';

// Initizalize all locales for react-intl.
let locale = window.location.search.split('locale=')[1];
let locale_package = en;
if (locale != null && (locale === 'ja')) {
  locale_package = ja;
}

const App = () => (
  <Router>
    <Switch>
      <Route exact path="/" component={Home} />
      <Route path="/sign-up" component={SignUp} />
      <Route path="/log-in" component={LogIn} />
    </Switch>
  </Router>
);

export const flattenMessages = ((nestedMessages, prefix = '') => {
  if (nestedMessages === null) {
    return {}
  }
  return Object.keys(nestedMessages).reduce((messages, key) => {
    const value       = nestedMessages[key]
    const prefixedKey = prefix ? `${prefix}.${key}` : key

    if (typeof value === 'string') {
      Object.assign(messages, { [prefixedKey]: value })
    } else {
      Object.assign(messages, flattenMessages(value, prefixedKey))
    }

    return messages
  }, {})
})

ReactDOM.render(<IntlProvider locale={locale} messages={flattenMessages(locale_package)}><App /></IntlProvider>, document.getElementById("root"));
