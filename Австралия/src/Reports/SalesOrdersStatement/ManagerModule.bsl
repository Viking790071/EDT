#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.ReportsOptions

// See ReportsOptionsOverridable.CustomizeReportsOptions.
//
Procedure CustomizeReportOptions(Settings, ReportSettings) Export

	ReportSettings.DefineFormSettings = True;
	ReportSettings.Description = NStr("en = 'Orders statement'; ru = 'Ведомость заказов покупателей';pl = 'Zestawienie zamówień';es_ES = 'Declaración de órdenes';es_CO = 'Declaración de órdenes';tr = 'Sipariş ekstresi';it = 'Resoconto ordine';de = 'Bestellungsnachweis'");
	
	OptionSettings = ReportsOptions.OptionDetails(
		Settings,
		Metadata.Reports.SalesOrdersStatement,
		"StatementForExternalUsers");
		
	OptionSettings.Enabled = False;
	
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#EndIf