#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.ReportsOptions

// See ReportsOptionsOverridable.CustomizeReportOptions. 
//
Procedure CustomizeReportOptions(Settings, ReportSettings) Export
	ModuleReportsOptions = Common.CommonModule("ReportsOptions");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "DeferredUpdateProgress");
	OptionSettings.Details = NStr("ru = 'Прогресс выполнения дополнительных процедур обработки данных.'; en = 'Progress of additional data processing procedures.'; pl = 'Postęp wykonania dodatkowych procedur przetwarzania danych.';es_ES = 'El progreso de realizar los procedimientos adicionales del procesamiento de datos.';es_CO = 'El progreso de realizar los procedimientos adicionales del procesamiento de datos.';tr = 'Ek veri işleme prosedürleri yürütülüyor.';it = 'Progresso di esecuzione delle ulteriori procedure di elaborazione dei dati.';de = 'Fortschritte bei zusätzlichen Datenverarbeitungsverfahren.'");
	OptionSettings.SearchSettings.Keywords = NStr("ru = 'Отложенное обновление'; en = 'Deferred update'; pl = 'Odroczona aktualizacja';es_ES = 'Actualización diferida';es_CO = 'Actualización diferida';tr = 'Gelecek döneme ait güncelleme';it = 'Aggiornamento posticipato';de = 'Verzögerte Aktualisierung'");
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#EndIf