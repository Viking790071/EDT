#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.ReportsOptions

// See ReportsOptionsOverridable.CustomizeReportOptions. 
//
Procedure CustomizeReportOptions(Settings, ReportSettings) Export
	
	ModuleReportsOptions = Common.CommonModule("ReportsOptions");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "Main");
	OptionSettings.Details = NStr("ru = 'Проверка целостности тома.'; en = 'Checking volume integrity.'; pl = 'Sprawdzenie integralności woluminu.';es_ES = 'Comprobar la integridad del tomo.';es_CO = 'Comprobar la integridad del tomo.';tr = 'Birim bütünlüğünün kontrolü.';it = 'Verifica dell''integrità del volume.';de = 'Überprüfung der Integrität des Volumes.'");
	
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#EndIf