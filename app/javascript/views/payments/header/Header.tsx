import * as React from "react";

import {
  Container,
  HeaderLink,
  HeaderText,
  Link,
  Navigation,
  Wrapper
} from "./HeaderStyle";

import locale from "../../../locale/en";
import Routes from "../../routes";

export default class Header extends React.Component {
  public render() {
    return (
      <Wrapper>
        <Container>
          <HeaderText>
            <HeaderLink href={Routes.payments.path}>
              {locale.payments.header.title}
            </HeaderLink>
          </HeaderText>
          <Navigation>
            {/* TODO add isSelected to props */}
            <Link
              active={this.isActive(Routes.payments.invoices.path)}
              href={Routes.payments.invoices.path}
            >
              {locale.payments.header.navigation.invoices}
            </Link>
            <Link
              active={this.isActive(Routes.payments.reports.path)}
              href={Routes.payments.reports.path}
            >
              {locale.payments.header.navigation.reports}
            </Link>
          </Navigation>
        </Container>
      </Wrapper>
    );
  }

  private isActive = path => {
    return window.location.href.indexOf(path) !== -1;
  };
}
