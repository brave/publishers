import React from "react";
import ReactDOM from "react-dom";
import { FormattedMessage, IntlProvider, useIntl } from "react-intl";
import AvatarEditor from "react-avatar-editor";

import "babel-polyfill";

import BannerPreview from "../packs/banner_preview.jsx";
import Navbar from "../packs/navbar.jsx";

import FailureDialog from "./bannerEditor/FailureDialog";

import styled from "styled-components";
import {
  Editor,
  Template,
  Content,
  Links,
  ExplanatoryText,
  Donations,
  Logo,
  Cover,
  Input,
  Label,
  Text,
  Caret,
  LinkInputWrapper,
  TextInput,
  DropdownToggle,
  Channel,
  Delete,
  Link,
  TextArea,
  DonationWrapper,
  Button,
  Opacity,
  Dialogue
} from "../packs/style.jsx";

import DonationJar from "../../assets/images/icn-donation-jar@1x.png";
import Spinner from "../utils/spinner";

import { initLocale } from "brave-ui";
import locale from "locale/en";
import en, { flattenMessages } from "../locale/en";
import ja from "../locale/ja";

import {
  BatColorIcon,
  YoutubeColorIcon,
  TwitterColorIcon,
  TwitchColorIcon,
  LoaderIcon
} from "brave-ui/components/icons";
import Select from "brave-ui/components/formControls/select";
import Checkbox from "brave-ui/components/formControls/checkbox";
import Toggle from "brave-ui/components/formControls/toggle";

import "../../assets/stylesheets/components/banner-editor.scss";
import "../../assets/stylesheets/components/spinner.scss";
import "../../assets/stylesheets/components/slider.scss";

const DEFAULT_TITLE = "Brave Rewards";
const DEFAULT_DESCRIPTION =
  "Thanks for stopping by. We joined Brave's vision of protecting your privacy because we believe that fans like you would support us in our effort to keep the web a clean and safe place to be.\n\nYour tip is much appreciated and it encourages us to continue to improve our content"
const DEFAULT_AMOUNTS = [1, 10, 100];

export default class BannerEditor extends React.Component {
  constructor(props) {
    super(props);

    const locale = document.body.dataset.locale;
    let localePackage = en;
    if (locale === "ja") {
      localePackage = ja;
    }
    this.state = {
      loading: true,
      title: this.props.values.title || DEFAULT_TITLE,
      description: this.props.values.description || localePackage.siteBanner.defaultDescription,
      logo: this.props.values.logo || { url: null, data: null },
      cover: this.props.values.cover || { url: null, data: null },
      channelIndex: this.props.values.channelIndex || 0,
      channelBanners: this.props.channelBanners,
      defaultSiteBanner: this.props.defaultSiteBanner,
      defaultSiteBannerMode: this.props.defaultSiteBannerMode,
      scale: 1,
      linkSelection: false,
      linkOption: "Youtube",
      currentUsername: "",
      youtube: this.props.values.youtube || "",
      twitter: this.props.values.twitter || "",
      twitch: this.props.values.twitch || "",
      donationAmounts: this.props.values.donationAmounts || DEFAULT_AMOUNTS,
      conversionRate: this.props.conversionRate,
      preferredCurrency: "USD",
      mode: "Edit",
      view: "editor-view",
      state: "editor"
    };
    this.updateTitle = this.updateTitle.bind(this);
    this.preview = this.preview.bind(this);
    this.updateDescription = this.updateDescription.bind(this);
    this.save = this.save.bind(this);
    this.toggleDefaultSiteBannerMode = this.toggleDefaultSiteBannerMode.bind(
      this
    );
    this.incrementChannelIndex = this.incrementChannelIndex.bind(this);
    this.decrementChannelIndex = this.decrementChannelIndex.bind(this);
    this.currentPlaceholder = this.currentPlaceholder.bind(this);
    this.updateCurrentUsername = this.updateCurrentUsername.bind(this);
    this.updateYoutube = this.updateYoutube.bind(this);
    this.updateTwitter = this.updateTwitter.bind(this);
    this.updateTwitch = this.updateTwitch.bind(this);
    this.updateWindowDimensions = this.updateWindowDimensions.bind(this);
  }

  componentWillMount() {
    this.modalize();
  }

  componentDidMount() {
    this.fetchBanner();
    this.setSpinner();
    this.cleanup();
    window.addEventListener("resize", this.updateWindowDimensions);
  }

  updateWindowDimensions() {
    if (window.innerWidth < 991) {
      this.close();
    }
  }

  modalize() {
    document.getElementsByClassName("modal-panel")[0].style.maxWidth = "none";
    document.getElementsByClassName("modal-panel")[0].style.padding = "0px";
    document.getElementsByClassName("modal-panel--content")[0].style.padding =
      "0px";
  }

  close() {
    document.getElementsByClassName("modal-panel")[0].style.maxWidth = "40rem";
    document.getElementsByClassName("modal-panel")[0].style.padding =
      "2rem 2rem";
    document.getElementsByClassName("modal-panel--content")[0].style.padding =
      "1rem 1rem 0 1rem";
    document.getElementsByClassName(
      "modal-panel--close js-deny"
    )[0].style.visibility = "visible";
    document.getElementsByClassName("modal-panel--close js-deny")[0].click();
  }

  cleanup() {
    document.getElementsByClassName(
      "modal-panel--close js-deny"
    )[0].style.visibility = "hidden";
    document.getElementById(
      "bat-select"
    ).childNodes[0].childNodes[0].style.color = "white";
    document.getElementById("bat-select").style.cursor = "pointer";
    document.getElementById("banner-toggle").style.cursor = "pointer";
  }

  preview() {
    let div = document.createElement("div");
    div.id = "preview-container";
    let PreviewContainer = document.body.appendChild(div);

    ReactDOM.render(<BannerPreview {...this.state} />, PreviewContainer);
    this.close();
  }

  setSpinner() {
    Spinner.show("spinner", "spinner-container");
  }

  setEditorRef = editor => (this.editor = editor);

  handleZoom(e) {
    this.setState({ scale: e.target.value });
  }

  apply() {
    let that = this;
    let logo = this.state.logo;
    let cover = this.state.cover;
    let img = this.editor.getImage();

    switch (this.state.state) {
      case "logo":
        let logoCanvas = document.createElement("canvas");
        logoCanvas.width = 480;
        logoCanvas.height = 480;
        var ctx = logoCanvas.getContext("2d");
        ctx.drawImage(img, 0, 0, 480, 480);
        logo.url = logoCanvas.toDataURL("image/jpeg", 1);

        //Generate data to save
        logoCanvas.toBlob(function(blob) {
          let file = {};
          file["files"] = [blob];
          logo.data = file;
          that.setState({ logo: logo, scale: 1, state: "editor" });
        });
        break;
      case "cover":
        let coverCanvas = document.createElement("canvas");
        coverCanvas.width = 2700;
        coverCanvas.height = 528;
        var ctx = coverCanvas.getContext("2d");
        ctx.drawImage(img, 0, 0, 2700, 528);
        cover.url = coverCanvas.toDataURL("image/jpeg", 1);

        //Generate data to save
        coverCanvas.toBlob(function(blob) {
          let file = {};
          file["files"] = [blob];
          cover.data = file;
          that.setState({ cover: cover, scale: 1, state: "editor" });
        });
        break;
    }
  }

  addLogo(event) {
    let temp = URL.createObjectURL(event.target.files[0]);
    this.setState({
      tempLogo: temp,
      state: "logo"
    });
  }

  addCover(event) {
    let temp = URL.createObjectURL(event.target.files[0]);
    this.setState({
      tempCover: temp,
      state: "cover"
    });
  }

  async fetchBanner() {
    let that = this;

    if (this.props.mode === "Editor-From-Preview" && !this.state.fetch) {
      that.setState({ loading: false });
    } else {
      let url =
        "/publishers/" +
        document.getElementById("publisher_id").value +
        "/site_banners/";
      this.state.defaultSiteBannerMode
        ? (url += this.props.defaultSiteBanner.id)
        : (url += this.props.channelBanners[this.state.channelIndex].id);

      let options = {
        method: "GET",
        credentials: "same-origin",
        headers: {
          Accept: "text/html",
          "X-Requested-With": "XMLHttpRequest",
          "X-CSRF-Token": document.head.querySelector("[name=csrf-token]")
            .content
        }
      };

      let response = await fetch(url, options);
      if (response.status >= 400) {
        location.reload();
      }
      let banner = await response.json();

      //500ms timeout prevents quick flash when load times are fast.
      setTimeout(async () => {
        if (banner) {
          banner.socialLinks = banner.socialLinks || {}
          that.setState({
            title: banner.title || DEFAULT_TITLE,
            description: banner.description || DEFAULT_DESCRIPTION,
            youtube: banner.socialLinks.youtube || "",
            twitter: banner.socialLinks.twitter || "",
            twitch: banner.socialLinks.twitch || "",
            donationAmounts: banner.donationAmounts || DEFAULT_AMOUNTS,
            logo: { url: banner.logoUrl || null, data: null },
            cover: { url: banner.backgroundUrl || null, data: null },
            loading: false,
            fetch: false
          });
        } else {
          that.setState({ loading: false });
        }
        if (this.props.mode === "Preview") {
          this.preview();
        }
      }, 500);
    }
  }

  handleLinkSelection(e) {
    let toggle = document.getElementById("toggle");
    if (e.target === toggle) {
      this.setState({ linkSelection: !this.state.linkSelection });
    } else {
      this.setState({ linkSelection: false });
    }
  }

  addLink() {
    switch (this.state.linkOption) {
      case "Youtube":
        this.setState({
          youtube: "https://www.youtube.com/" + this.state.currentUsername
        });
        break;
      case "Twitter":
        this.setState({
          twitter: "https://www.twitter.com/" + this.state.currentUsername
        });
        break;
      case "Twitch":
        this.setState({
          twitch: "https://www.twitch.tv/" + this.state.currentUsername
        });
        break;
    }
    this.setState({ currentUsername: "" });
  }

  currentPlaceholder() {
    const locale = document.body.dataset.locale;
    let localePackage = en;
    if (locale === "ja") {
      localePackage = ja;
    }
    switch (this.state.linkOption) {
      case "Youtube":
        return localePackage.siteBanner.youtubeHint;
      case "Twitter":
        return localePackage.siteBanner.twitterHint;
      case "Twitch":
        return localePackage.siteBanner.twitchHint;
    }
    return "";
  }

  handleLinkDelete(option) {
    switch (option) {
      case "Youtube":
        this.setState({ youtube: "" });
        break;
      case "Twitter":
        this.setState({ twitter: "" });
        break;
      case "Twitch":
        this.setState({ twitch: "" });
        break;
    }
  }

  handleLinkOption(value) {
    this.setState({ linkOption: value });
  }

  updateCurrentUsername(event) {
    this.setState({
      currentUsername: event.target.value.replace("/^a-zA-Z0-9._/g", "")
    });
  }

  updateTitle(event) {
    this.setState({ title: event.target.value });
  }

  updateDescription(event) {
    this.setState({ description: event.target.value });
  }

  updateYoutube(event) {
    this.setState({ youtube: event.target.value });
  }

  updateTwitter(event) {
    this.setState({ twitter: event.target.value });
  }

  updateTwitch(event) {
    this.setState({ twitch: event.target.value });
  }

  updateDonationAmounts(event, index) {
    let temp = this.state.donationAmounts;
    if (/^(\s*|\d+)$/.test(event.target.value)) {
      temp[index] = event.target.value;
      this.setState({ donationAmounts: temp });
    }
  }

  setEditMode = () => {
    this.setState({ state: "Editor" });
  };

  renderDialogue() {
    let dialogue;

    switch (this.state.state) {
      case "logo":
        dialogue = (
          <div>
            <Opacity />
            <Dialogue logo>
              <Text dialogueHeader>
                <FormattedMessage id="siteBanner.resizeLogoLabel" />
              </Text>
              <AvatarEditor
                ref={this.setEditorRef}
                image={this.state.tempLogo}
                width={180}
                height={180}
                border={20}
                borderRadius={160}
                color={[230, 236, 240, 0.6]}
                scale={this.state.scale}
                style={{ marginTop: "20px", cursor: "move" }}
              />
              <br />
              <input
                style={{
                  width: "120px",
                  textAlign: "center",
                  marginTop: "30px",
                  marginBottom: "40px"
                }}
                onChange={e => this.handleZoom(e)}
                type="range"
                value={this.state.scale}
                min={1}
                max={2}
                step={0.01}
              />
              <br />
              <Button
                onClick={() => this.setState({ state: "Editor" })}
                style={{ margin: "10px", width: "120px" }}
                outline
              >
                <FormattedMessage id="siteBanner.cancel" />
              </Button>
              <Button
                onClick={() => this.apply()}
                style={{ margin: "10px", width: "120px" }}
                primary
              >
                <FormattedMessage id="siteBanner.apply" />
              </Button>
            </Dialogue>
          </div>
        );
        break;
      case "cover":
        dialogue = (
          <div>
            <Opacity />
            <Dialogue cover>
              <Text dialogueHeader>
                <FormattedMessage id="siteBanner.resizeBackgroundImage" />
              </Text>
              <AvatarEditor
                ref={this.setEditorRef}
                image={this.state.tempCover}
                width={450}
                height={88}
                border={20}
                color={[230, 236, 240, 0.6]}
                scale={this.state.scale}
                style={{ marginTop: "20px", cursor: "move" }}
              />
              <br />
              <input
                style={{
                  width: "120px",
                  textAlign: "center",
                  marginTop: "30px",
                  marginBottom: "40px"
                }}
                onChange={e => this.handleZoom(e)}
                type="range"
                value={this.state.scale}
                min={1}
                max={2}
                step={0.01}
              />
              <br />
              <Button
                onClick={() => this.setState({ state: "Editor" })}
                style={{ margin: "10px", width: "120px" }}
                outline
              >
                <FormattedMessage id="siteBanner.cancel" />
              </Button>
              <Button
                onClick={() => this.apply()}
                style={{ margin: "10px", width: "120px" }}
                primary
              >
                <FormattedMessage id="siteBanner.apply" />
              </Button>
            </Dialogue>
          </div>
        );
        break;
      case "save":
        dialogue = (
          <div>
            <Opacity />
            <Dialogue id="save-container" save>
              {this.state.saving === false && (
                <div>
                  <Text dialogueHeader>
                    <FormattedMessage id="siteBanner.update24Hours" />
                  </Text>
                  <Button dialoguePrimary onClick={this.setEditMode}>
                    OK
                  </Button>
                </div>
              )}
            </Dialogue>
          </div>
        );
        break;
      case "error":
        dialogue = (
          <FailureDialog
            saving={this.state.saving}
            setEditMode={this.setEditMode}
            message={this.state.errorMessage}
          />
        );
        break;
      case "same":
        dialogue = (
          <div>
            <Opacity />
            <Dialogue save>
              <Text dialogueHeader>
                <FormattedMessage id="siteBanner.oneBannerHeader" />
              </Text>
              <Text dialogueSubtext>
                <FormattedMessage id="siteBanner.oneBannerSubText" />
              </Text>
              <div style={{ marginTop: "40px", textAlign: "center" }}>
                <Button
                  onClick={() => this.setState({ state: "Editor" })}
                  style={{ margin: "10px", width: "120px" }}
                  outline
                >
                  <FormattedMessage id="siteBanner.cancel" />
                </Button>
                <Button
                  onClick={async () => {
                    let toggle = await this.setDefaultSiteBannerMode(true);
                    this.setState(
                      {
                        defaultSiteBannerMode: !this.state
                          .defaultSiteBannerMode,
                        state: "Editor",
                        loading: true
                      },
                      () => {
                        this.fetchBanner();
                      }
                    );
                  }}
                  style={{ margin: "10px", width: "120px" }}
                  primary
                >
                  <FormattedMessage id="siteBanner.apply" />
                </Button>
              </div>
            </Dialogue>
          </div>
        );
        break;
    }
    return dialogue;
  }

  renderLinkInput() {
    return (
      this.state.youtube === "" ||
      this.state.twitter === "" ||
      this.state.twitch === ""
    );
  }

  renderLoadingScreen() {
    let visibility = "hidden";
    if (this.state.loading === true) {
      visibility = "visible";
    }
    return (
      <div
        style={{
          width: "100%",
          height: "744px",
          position: "absolute",
          zIndex: "20000",
          backgroundColor: "rgba(233, 240, 255, 1)",
          borderRadius: "8px",
          visibility: visibility
        }}
      >
        <div
          style={{
            width: "100%",
            marginTop: "auto",
            marginBottom: "auto",
            position: "absolute",
            left: "0",
            right: "0",
            top: "300px",
            bottom: "0"
          }}
          id="spinner-container"
        />
      </div>
    );
  }

  renderIcon(option) {
    switch (option) {
      case "Youtube":
        return (
          <YoutubeColorIcon
            style={{
              height: "30px",
              width: "30px",
              display: "inline",
              marginBottom: "4px",
              cursor: "pointer"
            }}
          />
        );
      case "Twitter":
        return (
          <TwitterColorIcon
            style={{
              height: "30px",
              width: "30px",
              display: "inline",
              marginBottom: "4px",
              cursor: "pointer"
            }}
          />
        );
      case "Twitch":
        return (
          <TwitchColorIcon
            style={{
              height: "30px",
              width: "30px",
              display: "inline",
              marginBottom: "4px",
              cursor: "pointer"
            }}
          />
        );
    }
  }

  renderLinks() {
    return (
      <div>
        {this.state.youtube !== "" && (
          <Link>
            <YoutubeColorIcon
              className="banner-link-option"
              style={{
                height: "25px",
                width: "25px",
                display: "inline-block",
                marginBottom: "12px"
              }}
            />
            <Channel>
              <Delete onClick={() => this.handleLinkDelete("Youtube")}>
                (X)
              </Delete>
              {this.state.youtube}
            </Channel>
          </Link>
        )}
        {this.state.twitter !== "" && (
          <Link>
            <TwitterColorIcon
              className="banner-link-option"
              style={{
                height: "25px",
                width: "25px",
                display: "inline-block",
                marginBottom: "12px"
              }}
            />
            <Channel>
              <Delete onClick={() => this.handleLinkDelete("Twitter")}>
                (X)
              </Delete>
              {this.state.twitter}
            </Channel>
          </Link>
        )}
        {this.state.twitch !== "" && (
          <Link>
            <TwitchColorIcon
              className="banner-link-option"
              style={{
                height: "25px",
                width: "25px",
                display: "inline-block",
                marginBottom: "12px"
              }}
            />
            <Channel>
              <Delete onClick={() => this.handleLinkDelete("Twitch")}>
                (X)
              </Delete>
              {this.state.twitch}
            </Channel>
          </Link>
        )}
      </div>
    );
  }

  renderDropdown() {
    if (this.state.linkSelection) {
      return (
        <div
          style={{
            position: "absolute",
            backgroundColor: "white",
            height: "100px",
            width: "55px",
            borderRadius: "4px",
            marginLeft: "11px",
            paddingTop: "5px",
            marginTop: "5px",
            border: "1px solid lightGray",
            boxShadow: "0 3px 4px rgba(0,0,0,0.16), 0 3px 4px rgba(0,0,0,0.23)"
          }}
        >
          <div
            onClick={() => this.handleLinkOption("Youtube")}
            className="banner-link-option"
            style={{ textAlign: "center", margin: "2px", cursor: "pointer" }}
          >
            <YoutubeColorIcon
              style={{ height: "25px", width: "25px", margin: "auto" }}
            />
          </div>
          <div
            onClick={() => this.handleLinkOption("Twitter")}
            className="banner-link-option"
            style={{ textAlign: "center", margin: "2px", cursor: "pointer" }}
          >
            <TwitterColorIcon
              style={{ height: "25px", width: "25px", margin: "auto" }}
            />
          </div>
          <div
            onClick={() => this.handleLinkOption("Twitch")}
            className="banner-link-option"
            style={{ textAlign: "center", margin: "2px", cursor: "pointer" }}
          >
            <TwitchColorIcon
              style={{ height: "25px", width: "25px", margin: "auto" }}
            />
          </div>
        </div>
      );
    }
  }

  tipToOption() {
    switch (this.state.donationAmounts.join(",")) {
      case "1,5,10":
      case "1,10,100":
        return 0;
      case "5,10,20":
        return 1;
        break;
      case "10,20,50":
        return 2;
        break;
      case "20,50,100":
        return 3;
        break;
    }
  }

  handleTipSelection(key, child) {
    switch (key) {
      case "0":
        this.setState({ donationAmounts: DEFAULT_AMOUNTS });
        break;
      case "1":
        this.setState({ donationAmounts: [5, 10, 20] });
        break;
      case "2":
        this.setState({ donationAmounts: [10, 20, 50] });
        break;
      case "3":
        this.setState({ donationAmounts: [20, 50, 100] });
        break;
    }
  }

  async save() {
    this.setState({ state: "save", saving: "true" }, () =>
      Spinner.show("save-spinner", "save-container")
    );

    let url =
      "/publishers/" +
      document.getElementById("publisher_id").value +
      "/site_banners/";
    this.state.defaultSiteBannerMode
      ? (url += this.props.defaultSiteBanner.id)
      : (url += this.props.channelBanners[this.state.channelIndex].id);

    let body = new FormData();
    body.append("title", this.state.title);
    body.append("description", this.state.description);
    body.append("donation_amounts", JSON.stringify(this.state.donationAmounts));
    body.append(
      "social_links",
      JSON.stringify({
        youtube: this.state.youtube,
        twitter: this.state.twitter,
        twitch: this.state.twitch
      })
    );

    if (this.state.logo.data) {
      let logo = await this.readData(this.state.logo.data);
      body.append("logo", logo);
    }
    if (this.state.cover.data) {
      let cover = await this.readData(this.state.cover.data);
      body.append("cover", cover);
    }

    let options = {
      method: "PUT",
      credentials: "same-origin",
      headers: {
        Accept: "text/html",
        "X-Requested-With": "XMLHttpRequest",
        "X-CSRF-Token": document.head.querySelector("[name=csrf-token]").content
      },
      body: body
    };

    let save = await fetch(url, options);
    if (save.status == 400) {
      const errorMessage = await save.json();
      const { message } = errorMessage;

      this.setState({
        saving: false,
        state: "error",
        errorMessage: message
      });
      // location.reload();
    } else if (save.status > 400) {
      this.setState({
        saving: false,
        state: "error",
        errorMessage: "A critical error has occurred. Please try again later"
      });
    }

    document.getElementById("save-spinner").remove();
    this.setState({ saving: false });
  }

  readData(file) {
    let reader = new FileReader();
    reader.readAsDataURL(file.files[0]);
    return new Promise(
      resolve =>
        (reader.onloadend = function() {
          resolve(reader.result);
        })
    );
  }

  incrementChannelIndex() {
    this.setState(
      prevState => {
        return {
          channelIndex: (prevState.channelIndex += 1),
          loading: true,
          fetch: true
        };
      },
      () => {
        this.fetchBanner();
      }
    );
  }

  decrementChannelIndex() {
    this.setState(
      prevState => {
        return {
          channelIndex: (prevState.channelIndex -= 1),
          loading: true,
          fetch: true
        };
      },
      () => {
        this.fetchBanner();
      }
    );
  }

  async toggleDefaultSiteBannerMode() {
    if (this.state.defaultSiteBannerMode === true) {
      let toggle = await this.setDefaultSiteBannerMode(false);
      this.setState(
        {
          defaultSiteBannerMode: !this.state.defaultSiteBannerMode,
          loading: true,
          fetch: true
        },
        () => {
          this.fetchBanner();
        }
      );
    } else {
      this.setState({ state: "same", fetch: true });
    }
  }

  async setDefaultSiteBannerMode(value) {
    let url =
      "/publishers/" +
      document.getElementById("publisher_id").value +
      "/site_banners/set_default_site_banner_mode?dbm=" +
      value;
    let options = {
      method: "POST",
      credentials: "same-origin",
      headers: {
        Accept: "text/html",
        "X-Requested-With": "XMLHttpRequest",
        "X-CSRF-Token": document.head.querySelector("[name=csrf-token]").content
      }
    };
    let response = await fetch(url, options);
    if (response.status >= 400) {
      location.reload();
    }
  }

  render() {
    initLocale(locale);
    const locale = document.body.dataset.locale;
    let localePackage = en;
    if (locale === "ja") {
      localePackage = ja;
    }
    return (
      <IntlProvider locale={locale} messages={flattenMessages(localePackage)}>
      <Editor onClick={e => this.handleLinkSelection(e)}>
        {this.renderLoadingScreen()}
        {this.renderDialogue()}

        <Navbar
          defaultSiteBanner={this.props.defaultSiteBanner}
          channelBanners={this.props.channelBanners}
          channelIndex={this.state.channelIndex}
          defaultSiteBannerMode={this.state.defaultSiteBannerMode}
          incrementChannelIndex={this.incrementChannelIndex}
          decrementChannelIndex={this.decrementChannelIndex}
          toggleDefaultSiteBannerMode={this.toggleDefaultSiteBannerMode}
          save={this.save}
          close={this.close}
          preview={this.preview}
        />

        <Template>
          <Logo url={this.state.logo.url}>
            <Input type="file" id="logoInput" onChange={e => this.addLogo(e)} />
            <Label logo htmlFor="logoInput" />
          </Logo>

          <Cover url={this.state.cover.url}>
            <Input
              type="file"
              id="backgroundInput"
              onChange={e => this.addCover(e)}
            />
            <Label htmlFor="backgroundInput" />
          </Cover>

          <Content>
            <Links>
              <Text links>
                <FormattedMessage id="siteBanner.links" />
              </Text>

              {this.renderLinks()}

              {this.renderLinkInput() && (
                <LinkInputWrapper>
                  <DropdownToggle>
                    {this.renderIcon(this.state.linkOption)}
                    <Caret onClick={e => this.toggleDropdown(e)} id="toggle">
                      &#9662;
                    </Caret>
                  </DropdownToggle>
                  <TextInput
                    link
                    placeholder={this.currentPlaceholder()}
                    placeholderTextColor="#707070"
                    onChange={this.updateCurrentUsername}
                    value={this.state.currentUsername}
                    maxLength={80}
                  />
                  {this.renderDropdown()}
                  <Text add onClick={() => this.addLink()}>
                    <FormattedMessage id="siteBanner.addChannel" />
                  </Text>
                </LinkInputWrapper>
              )}
            </Links>

            <ExplanatoryText>
              <TextInput
                headline
                onChange={this.updateTitle}
                value={this.state.title}
                maxLength={21}
                type="text"
              />
              <TextArea
                description
                onChange={this.updateDescription}
                value={this.state.description}
                maxLength={330}
                type="text"
              />
            </ExplanatoryText>

            <Donations>
              <Text donations>
                <FormattedMessage id="siteBanner.tipOptionsHeader" />
              </Text>
              <div
                style={{ width: "75%", margin: "auto", paddingBottom: "20px" }}
              >
                <Select
                  id="bat-select"
                  value={this.tipToOption()}
                  type={"light"}
                  title={"Limit Sites to"}
                  disabled={false}
                  floating={false}
                  onChange={(key, child) => this.handleTipSelection(key, child)}
                >
                  <div data-value="0">
                    <FormattedMessage id="siteBanner.tipOption1" />
                  </div>
                  <div data-value="1">
                    <FormattedMessage id="siteBanner.tipOption2" />
                  </div>
                  <div data-value="2">
                    <FormattedMessage id="siteBanner.tipOption3" />
                  </div>
                  <div data-value="3">
                    <FormattedMessage id="siteBanner.tipOption4" />
                  </div>
                </Select>
              </div>
              <DonationWrapper>
                <Button donation>
                  <BatColorIcon
                    style={{
                      display: (locale === "ja") ? "none" : "inline",
                      height: "25px",
                      width: "25px",
                      marginRight: "10px"
                    }}
                  />
                  <Text donationAmount>{this.state.donationAmounts[0]}</Text>
                  <Text BAT>
                    <FormattedMessage id="siteBanner.batLocalized" />
                  </Text>
                </Button>
                <Text convertedAmount>
                  {(
                    this.state.donationAmounts[0] * this.props.conversionRate
                  ).toFixed(2)}{" "}
                  {this.props.preferredCurrency}
                </Text>
              </DonationWrapper>
              <DonationWrapper>
                <Button donation>
                  <BatColorIcon
                    style={{
                      display: (locale === "ja") ? "none" : "inline",
                      height: "25px",
                      width: "25px",
                      marginRight: "10px"
                    }}
                  />
                  <Text donationAmount>{this.state.donationAmounts[1]}</Text>
                  <Text BAT>
                    <FormattedMessage id="siteBanner.batLocalized" />
                  </Text>
                </Button>
                <Text convertedAmount>
                  {(
                    this.state.donationAmounts[1] * this.props.conversionRate
                  ).toFixed(2)}{" "}
                  {this.props.preferredCurrency}
                </Text>
              </DonationWrapper>
              <DonationWrapper>
                <Button donation>
                  <BatColorIcon
                    style={{
                      display: (locale === "ja") ? "none" : "inline",
                      height: "25px",
                      width: "25px",
                      marginRight: "10px"
                    }}
                  />
                  <Text donationAmount>{this.state.donationAmounts[2]}</Text>
                  <Text BAT>
                    <FormattedMessage id="siteBanner.batLocalized" />
                  </Text>
                </Button>
                <Text convertedAmount>
                  {(
                    this.state.donationAmounts[2] * this.props.conversionRate
                  ).toFixed(2)}{" "}
                  {this.props.preferredCurrency}
                </Text>
              </DonationWrapper>
            </Donations>
          </Content>
        </Template>
          </Editor>
            </IntlProvider>
    );
  }
}

export function renderBannerEditor(
  values,
  preferredCurrency,
  conversionRate,
  defaultSiteBannerMode,
  defaultSiteBanner,
  channelBanners,
  mode
) {
  let props = {
    values: values,
    preferredCurrency: preferredCurrency,
    conversionRate: conversionRate,
    defaultSiteBannerMode: defaultSiteBannerMode,
    defaultSiteBanner: defaultSiteBanner,
    channelBanners: channelBanners,
    mode: mode
  };

  ReactDOM.render(
    <BannerEditor {...props} />,
    document.getElementById("rewards-banner-container").parentElement
      .parentElement
  );
}
