#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.ReportsOptions

// See ReportsOptionsOverridable.CustomizeReportOptions. 
//
Procedure CustomizeReportOptions(Settings, ReportSettings) Export

	ReportSettings.DefineFormSettings = True;
	
	OptionSettings = ReportsOptions.OptionDetails(
		Settings,
		Metadata.Reports.StatementOfAccount,
		"StatementInCurrencyForExternalUsers");
		
	OptionSettings.Enabled = False;
	
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#EndIf