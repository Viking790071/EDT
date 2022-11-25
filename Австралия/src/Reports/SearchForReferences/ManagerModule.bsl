#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.ReportsOptions

// See ReportsOptionsOverridable.CustomizeReportOptions. 
//
Procedure CustomizeReportOptions(Settings, ReportSettings) Export
	ModuleReportsOptions = Common.CommonModule("ReportsOptions");
	ModuleReportsOptions.SetOutputModeInReportPanes(Settings, ReportSettings, False);
	
	ReportSettings.DefineFormSettings = True;
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "Main");
	OptionSettings.Enabled = False;
	OptionSettings.Details = NStr("ru = 'Поиск мест использования объектов приложения.'; en = 'Search for usage instances of application objects.'; pl = 'Wyszukiwanie lokalizacji wykorzystania obiektów aplikacji.';es_ES = 'Búsqueda de las ubicaciones de uso de los objetos de la aplicación.';es_CO = 'Búsqueda de las ubicaciones de uso de los objetos de la aplicación.';tr = 'Uygulama nesnelerinin kullanım yerlerini arayın.';it = 'Ricerca di istanze d''uso degli oggetti dell''applicazione.';de = 'Suchen Sie nach Verwendungsorten von Anwendungsobjekten.'");
EndProcedure

// It is intended to be called from the ReportOptionsOverridable.BeforeAddReportCommands procedure.
// 
// Parameters:
//   ReportCommands - ValueTable - table of commands to be shown in the submenu.
//                                      See ReportsOptionsOverridable.BeforeAddReportsCommands. 
//
// Returns:
//   ValueTableRow, Undefined - if you do not have rights to view the report, added command or Undefined.
//
Function AddUsageInstanceCommand(ReportCommands) Export
	If Not AccessRight("View", Metadata.Reports.SearchForReferences) Then
		Return Undefined;
	EndIf;
	Command = ReportCommands.Add();
	Command.Presentation      = NStr("ru = 'Места использования'; en = 'Usage instances'; pl = 'Liczba lokalizacji użytkowania';es_ES = 'Ubicaciones de uso';es_CO = 'Ubicaciones de uso';tr = 'Kullanım yerleri';it = 'Istanze di utilizzo';de = 'Verwendungsstandorte'");
	Command.MultipleChoice = True;
	Command.Importance           = "SeeAlso";
	Command.FormParameterName  = "Filter.RefSet";
	Command.VariantKey       = "Main";
	Command.Manager           = "Report.SearchForReferences";
	Return Command;
EndFunction

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#EndIf