import React from 'react'
import { FormattedMessage, IntlProvider, useIntl } from "react-intl";
import styled from 'styled-components'
import { Container, BrandBar, ControlBar, BrandImage, BrandText, ToggleText, ToggleWrapper, Button, Channels, Text} from '../packs/style.jsx'

import DonationJar from '../../assets/images/icn-donation-jar@1x.png'
import Toggle from 'brave-ui/components/formControls/toggle'
import { YoutubeColorIcon, TwitterColorIcon, TwitchColorIcon, CaratLeftIcon, CaratRightIcon, VerifiedIcon} from 'brave-ui/components/icons'
import { initLocale } from 'brave-ui'
import locale from 'locale/en'
import en, { flattenMessages } from "../locale/en"
import ja from "../locale/ja"

export default class Navbar extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      toggled: false,
    }
  }

  render(){
    initLocale(locale);
    const docLocale = document.body.dataset.locale;
    let localePackage = en;
    if (docLocale === "ja") {
      localePackage = ja;
    }
    return(
      <IntlProvider locale={docLocale} messages={flattenMessages(localePackage)}>
      <Container>

        <BrandBar>
          <BrandImage src={DonationJar}/>
          <BrandText>
            <FormattedMessage id="siteBanner.header" />
          </BrandText>
          <ToggleText>
            <FormattedMessage id="siteBanner.toggleSharedBannerContent" />
          </ToggleText>
          <ToggleWrapper>
          {
            this.props.channelBanners.length > 0 ?
            <Toggle id='banner-toggle' checked={this.props.defaultSiteBannerMode} disabled={false} type={'light'} size={'large'} onToggle={this.props.toggleDefaultSiteBannerMode}></Toggle>
            :
            <Toggle id='banner-toggle' checked={this.props.defaultSiteBannerMode} disabled={false} type={'light'} size={'large'}></Toggle>
          }
          </ToggleWrapper>
        </BrandBar>

        <ControlBar>

          <Channels active={!this.props.defaultSiteBannerMode}>
            {
              this.props.channelIndex > 0 ?
              <CaratLeftIcon onClick={this.props.decrementChannelIndex} style={{height:'35px', width:'35px', marginBottom:'5px', color: '#fb542b', cursor:'pointer'}}/>
              :
              <CaratLeftIcon style={{height:'35px', width:'35px', marginBottom:'5px', color: '#C5C5D3', opacity:.3}}/>
            }
            {
              this.props.channelBanners.length > 0 ?
                <VerifiedIcon style={{height:'25px', width:'25px', marginBottom:'5px', marginRight:'5px', color: '#58CD92'}}/>
                : null
            }
            <Text channel style={{display:'inline'}}>
              {
                this.props.channelBanners.length > 0 ? this.props.channelBanners[this.props.channelIndex].name : null
              }
            </Text>
            {
              this.props.channelIndex < this.props.channelBanners.length-1 ?
              <CaratRightIcon onClick={this.props.incrementChannelIndex} style={{height:'35px', width:'35px', marginBottom:'5px', color: '#fb542b', cursor:'pointer'}}/>
              :
              <CaratRightIcon style={{height:'35px', width:'35px', marginBottom:'5px', color: '#C5C5D3', opacity:.3}}/>
            }
          </Channels>

          <Button onClick={this.props.preview} style={{marginLeft:'auto', marginRight:'20px'}} outline>
            <FormattedMessage id="siteBanner.previewButton" />
          </Button>
          <Button onClick={this.props.save} style={{marginRight:'20px'}} primary>
            <FormattedMessage id="siteBanner.saveChanges" />
          </Button>
          <Button onClick={this.props.close} subtle>
            <FormattedMessage id="siteBanner.closeBanner" />
          </Button>
        </ControlBar>

      </Container>
      </IntlProvider>
    )
  }
}
