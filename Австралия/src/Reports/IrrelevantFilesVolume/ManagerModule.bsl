#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.ReportsOptions

// See ReportsOptionsOverridable.CustomizeReportOptions. 
//
Procedure CustomizeReportOptions(Settings, ReportSettings) Export
	
	ModuleReportsOptions = Common.CommonModule("ReportsOptions");
	ModuleReportsOptions.SetOutputModeInReportPanes(Settings, ReportSettings, False);
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "IrrelevantFilesVolumeByOwners");
	OptionSettings.Details = NStr("ru = 'Позволяет получить информацию об объеме данных, занятых ненужными файлами.'; en = 'Allows you to get information on the amount of data used by unused files.'; pl = 'Umożliwia uzyskanie informacji o ilości danych, zajmowanych przez niepotrzebne pliki.';es_ES = 'Permite obtener la información de volumen de datos ocupados por los archivos no necesarios.';es_CO = 'Permite obtener la información de volumen de datos ocupados por los archivos no necesarios.';tr = 'Gereksiz dosyalar ile doldurulmuş veri hacmi hakkında bilgi alınmasına imkan sağlar.';it = 'Permette di avere più informazioni sulla quantità di dati occupata dai file non utilizzati.';de = 'Ermöglicht es Ihnen, Informationen über die Datenmenge zu erhalten, die durch unnötige Dateien belegt ist.'");
	
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#EndIf