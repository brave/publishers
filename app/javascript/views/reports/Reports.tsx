import * as React from "react";

import { Card, Cell, Container, Table, TableHeader, Wrapper } from "../style";

import PaymentsHeader from "../payments/header/Header";
import routes from "../routes";
import { FlexWrapper, LoadingIcon, ReportHeader } from "./ReportsStyle";

import locale from "../../locale/en";
import UploadDialog from "./uploadDialog/UploadDialog";

interface IReport {
  id: string;
  filename: string;
  file_url: string;
  uploaded_by_user: string;
  created_at: string;
}
interface IReportsProps {
  reports: IReport[];
}

interface IReportsState {
  showUpload: boolean;
  isLoading: boolean;
  reports: IReport[];
}

export default class Reports extends React.Component<
  IReportsProps,
  IReportsState
> {
  public readonly state: IReportsState = {
    isLoading: false,
    reports: this.props.reports,
    showUpload: false
  };
  constructor(props) {
    super(props);
    this.reloadTable = this.reloadTable.bind(this);
  }

  public setLoading = isLoading => {
    this.setState({ isLoading });
  };

  public async reloadTable() {
    this.setLoading(true);
    const result = await fetch(routes.payments.reports.path, {
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": document.head
          .querySelector("[name=csrf-token]")
          .getAttribute("content"),
        "X-Requested-With": "XMLHttpRequest"
      },
      method: "GET"
    }).then(response => {
      response.json().then(json => {
        this.setState({ reports: json.reports });
      });
    });

    this.setLoading(false);
  }

  public render() {
    return (
      <Wrapper>
        <PaymentsHeader />
        <Container>
          <Card>
            <FlexWrapper>
              <ReportHeader>{locale.payments.reports.title}</ReportHeader>
              <UploadDialog
                route={routes.payments.reports.path}
                text={locale.payments.reports.upload}
                afterSave={this.reloadTable}
                setLoading={this.setLoading}
              />
              <LoadingIcon isLoading={this.state.isLoading} />
            </FlexWrapper>

            {/* <Button onClick={this.reloadTable}>reload</Button> */}
            <Table>
              <thead>
                <tr>
                  <TableHeader>{locale.payments.reports.fileName}</TableHeader>
                  <TableHeader>{locale.payments.reports.amountBAT}</TableHeader>
                  <TableHeader>{locale.payments.reports.createdAt}</TableHeader>
                  <TableHeader>
                    {locale.payments.reports.uploadedBy}
                  </TableHeader>
                </tr>
              </thead>
              <tbody>
                {this.state.reports.map(report => (
                  <tr key={report.id}>
                    <Cell>
                      <a href={report.file_url}>{report.filename}</a>
                    </Cell>
                    <Cell>--</Cell>
                    <Cell>{report.created_at}</Cell>
                    <Cell>{report.uploaded_by_user}</Cell>
                  </tr>
                ))}
              </tbody>
            </Table>
          </Card>
        </Container>
      </Wrapper>
    );
  }
}
