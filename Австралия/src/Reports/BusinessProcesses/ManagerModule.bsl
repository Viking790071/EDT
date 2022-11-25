///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.ReportsOptions

// See ReportsOptionsOverridable.CustomizeReportsOptions. 
//
Procedure CustomizeReportOptions(Settings, ReportSettings) Export
	ModuleReportsOptions = Common.CommonModule("ReportsOptions");
	ReportSettings.Details = NStr("ru = 'Список и сводная статистика по всем бизнес-процессам.'; en = 'Business process list and summary.'; pl = 'Lista procesów biznesowych i skrót.';es_ES = 'Lista y resumen de procesos de negocio.';es_CO = 'Lista y resumen de procesos de negocio.';tr = 'İş süreçleri listesi ve özeti.';it = 'Elenco e statistiche riassuntive per tutti i processi aziendali.';de = 'Geschäftsprozessliste und -bericht.'");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "BusinessProcessesList");
	OptionSettings.Details = NStr("ru = 'Список бизнес-процессов определенных типов за указанный интервал.'; en = 'Business processes of certain types for the specified period.'; pl = 'Procesy biznesowe ustalonych typów dla określonego okresu.';es_ES = 'Procesos de negocio de ciertos tipos durante el período especificado.';es_CO = 'Procesos de negocio de ciertos tipos durante el período especificado.';tr = 'Belirtilen dönem için belirli iş süreci türleri.';it = 'Elenco di processi aziendali di determinati tipi per un intervallo specificato.';de = 'Geschäftsprozesse von bestimmten Typen für den angegebenen Zeitraum.'");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "StatisticsByKinds");
	OptionSettings.Details = NStr("ru = 'Сводная диаграмма по количеству активных и завершенных бизнес-процессов.'; en = 'Pivot chart of all active and completed business processes.'; pl = 'Tabela przestawna wszystkich aktywnych i zakończonych procesów biznesowych.';es_ES = 'Gráfico giratorio de todos los procesos de negocio activos y completados.';es_CO = 'Gráfico giratorio de todos los procesos de negocio activos y completados.';tr = 'Tüm devam eden ve tamamlanmış iş süreçlerinin özet grafiği.';it = 'Grafico riassuntivo del numero di processi aziendali attivi e completati.';de = 'Hauptdiagramm von allen aktiven und abgeschlossenen Geschäftsprozessen.'");
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#EndIf