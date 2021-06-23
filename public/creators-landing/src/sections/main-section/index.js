import React from "react";
import {
  Container,
  GradientBackground,
  H2,
  PrimaryButton,
  UserIcon,
  YouTubeIcon,
  PublicationIcon,
  TwitchIcon,
  SwoopBottom,
  StyledFormField
} from "../../components";

import { Link } from "react-router-dom";
import SignComponent from "./signComponent";
import batPill from "../../components/img/built-with-bat-pill.svg";
import { Heading, Box, Image, Anchor, Text, CheckBox, FormField } from "grommet";
import locale from '../../locale/en';
import { FormattedMessage, useIntl} from 'react-intl';


const logAction = (action, value) => {
  if (window._paq) {
    window._paq.push(["trackEvent", action, "Clicked", value]);
  }
};

export const MainHome = () => {
  return (
    <GradientBackground align="center">
      <Container role="main">
        <Box
          direction="column"
          pad="large"
          margin={{ top: "80px", bottom: "90px" }}
        >
          {(window.location.search.split('locale=')[1] !== 'ja') &&
            <Box
              className="bat-pill"
              as="a"
              href={locale.nav.batPillHref}
              aria-label={locale.nav.batPillAlt}
            >
              <Image src={batPill} />
            </Box>
          }
          <Heading level="1" color="white" margin={{ vertical: "small" }}>
            {<FormattedMessage id="main.home.headline"/>}
          </Heading>
          <H2 level="2" size="small" color="#E9E9F4">
            {<FormattedMessage id="main.home.subhead"/>}
          </H2>
          <Box direction="row" pad={{ vertical: "24px" }} width="100%" className="main-btns">
            <Link
              to={locale.main.home.btn.signupHref}
              onClick={() => logAction("StartSignupClicked", "Landing")}
            >
              <PrimaryButton
                label={<FormattedMessage id="main.home.btn.signup" />}
                name={locale.main.home.btn.signup}
                margin={{right: "medium"}}
              />
            </Link>
            <Link
              to={locale.main.home.btn.loginHref}
              onClick={() => logAction("StartSignupClicked", "Landing")}
            >
              <Anchor
                label={<FormattedMessage id="main.home.btn.login" />}
                name={locale.main.home.btn.login}
                color="white"
              />
            </Link>
          </Box>
          <Heading level="3" size="small" color="#E9E9F4">
            {<FormattedMessage id="main.home.examples.headline" />}
          </Heading>
          <Box direction="row-responsive" gap="24px">
            <Box direction="column">
              <Box direction="row" gap="small" margin={{ vertical: "8px" }}>
                <UserIcon />
                <Heading level="3" color="#E9E9F4" size="small" margin="0">
                  {<FormattedMessage id="main.home.examples.website" />}
                </Heading>
              </Box>
              <Box direction="row" gap="small" margin={{ vertical: "8px" }}>
                <YouTubeIcon />
                <Heading level="3" color="#E9E9F4" size="small" margin="0">
                  {<FormattedMessage id="main.home.examples.youtube" />}
                </Heading>
              </Box>
            </Box>
            <Box direction="column">
              <Box direction="row" gap="small" margin={{ vertical: "8px" }}>
                <PublicationIcon />
                <Heading level="3" color="#E9E9F4" size="small" margin="0">
                  {<FormattedMessage id="main.home.examples.publication" />}
                </Heading>
              </Box>
              <Box direction="row" gap="small" margin={{ vertical: "8px" }}>
                <TwitchIcon />
                <Heading level="3" color="#E9E9F4" size="small" margin="0">
                  {<FormattedMessage id="main.home.examples.Twitch" />}
                </Heading>
              </Box>
            </Box>
          </Box>
        </Box>
      </Container>
      <SwoopBottom />
    </GradientBackground>
  );
};

export const MainSignIn = () => {
  return (
    <SignComponent
      heading={<FormattedMessage id="main.signin.heading"/>}
      subhead={<FormattedMessage id="main.signin.subhead"/>}
      inputPlaceholder={<FormattedMessage id="main.signin.inputPlaceholder"/>}
      btn={<FormattedMessage id="main.signin.btn"/>}
      tinyOne={<FormattedMessage id="main.signin.tinyOne"/>}
      tinyOneHref={locale.main.signin.tinyOneHref}
      tinyTwo={<FormattedMessage id="main.signin.tinyTwo"/>}
      tinyTwoHref={locale.main.signin.tinyTwoHref}
      footerOne={<FormattedMessage id="main.footerOne"/>}
      footerOneHref={locale.main.footerOneHref}
      footerTwo={<FormattedMessage id="main.footerTwo"/>}
      footerTwoHref={locale.main.footerTwoHref}
      formId="signInForm"
      method="PUT"
    />
  );
};

const TermsOfService = props => {
  const intl = useIntl();
  const [checked, setChecked] = React.useState(false);

  return (
    <Text size="18px" color="rgba(255, 255, 255, .8)" textAlign="center">
      <FormattedMessage
        id="main.termsOfService.description"
        values={{
          a: msg => (
            <Anchor
              href="https://brave.com/publishers-creators-privacy/#brave-rewards"
              label={msg}
              style={{ textDecoration: "underline" }}
              color="rgba(255, 255, 255, .8)"
            />
          )
        }}
      />

      <StyledFormField
        required
        component={CheckBox}
        name="terms_of_service"
        justify="center"
        pad={true}
        checked={checked}
        label={intl.formatMessage({ id: "main.termsOfService.agree" })}
        validate={(fieldData, _) => {
          if (!fieldData) {
            return intl.formatMessage({ id: "main.termsOfService.invalid" })
          }
        }}
        onChange={event => {
          setChecked(event.target.checked);
        }}
      />
    </Text>
  );
};

export const MainSignUp = () => {
  return (
    <SignComponent
      heading={<FormattedMessage id="main.signup.heading"/>}
      subhead={<FormattedMessage id="main.signup.subhead"/>}
      inputPlaceholder={<FormattedMessage id="main.signup.inputPlaceholder"/>}
      btn={<FormattedMessage id="main.signup.btn"/>}
      tinyOne={<FormattedMessage id="main.signup.tinyOne"/>}
      tinyOneHref={locale.main.signup.tinyOneHref}
      footerOne={<FormattedMessage id="main.footerOne"/>}
      footerOneHref={locale.main.footerOneHref}
      footerTwo={<FormattedMessage id="main.footerTwo"/>}
      footerTwoHref={locale.main.footerTwoHref}
      formId="signUpForm"
      termsOfService={<TermsOfService />}
      method="POST"
    />
  );
};
