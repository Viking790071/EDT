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
	ReportSettings.Details = NStr("ru = 'Список и сводная статистика по выполнению заданий.'; en = 'Jobs and job execution summary.'; pl = 'Zadania i podsumowanie ich wykonania.';es_ES = 'Tareas y resumen de ejecución de tarea.';es_CO = 'Tareas y resumen de ejecución de tarea.';tr = 'Görevler ve görev tamamlama özeti.';it = 'Elenco e statistiche riassuntive sull''esecuzione delle attività.';de = 'Arbeiten und Bericht über Arbeitserfüllung.'");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "JobsList");
	OptionSettings.Details = NStr("ru = 'Список всех заданий за указанный период.'; en = 'All jobs for the specified period.'; pl = 'Wszystkie prace dla określonego okresu.';es_ES = 'Todos las tareas para el período especificado.';es_CO = 'Todos las tareas para el período especificado.';tr = 'Belirtilen dönem için tüm görevler.';it = 'Elenco di tutte le attività per il periodo specificato.';de = 'Alle Arbeiten für den angegebenen Zeitraum.'");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "JobsStatistics");
	OptionSettings.Details = NStr("ru = 'Сводная диаграмма по всем выполненным, отмененным заданиям и заданиям в работе.'; en = 'Pivot chart of all tasks that are completed, canceled, or in progress.'; pl = 'Tabela przestawna wszystkich zadań, które są zakończone, anulowane lub w toku.';es_ES = 'Gráfico giratorio de todas las tareas completadas, canceladas o en curso.';es_CO = 'Gráfico giratorio de todas las tareas completadas, canceladas o en curso.';tr = 'Tamamlanmış, iptal edilmiş ve devam eden tüm görevlerin özet grafiği.';it = 'Diagramma di riepilogo per tutte le attività completate e annullate e le attività nel lavoro.';de = 'Hauptdiagramm von allen erfüllten, abgebrochenen Aufgaben oder Aufgaben in Bearbeitung.'");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "CheckExecutionCyclesStatistics");
	OptionSettings.Details = NStr("ru = 'Топ 10 авторов по среднему количеству перепроверок заданий.'; en = 'Top 10 authors by average time of job counterchecks.'; pl = '10 najlepszych autorów według średniego czasu kontroli pracy.';es_ES = 'Top 10 de autores por tiempo promedio de las comprobaciones de la tarea.';es_CO = 'Top 10 de autores por tiempo promedio de las comprobaciones de la tarea.';tr = 'Ortalama tekrar kontrol etmeye göre en iyi 10 yazar.';it = '10 principali autori per il numero medio di controlli incrociati sul lavoro.';de = 'Top 10-Autoren nach durchschnittlicher Zeit von Arbeitsüberprüfung.'");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "DurationStatistics");
	OptionSettings.Details = NStr("ru = 'Топ 10 авторов по средней длительности выполнения заданий.'; en = 'Top 10 authors by average time of job completion.'; pl = '10 najlepszych autorów według średniego czasu wykonania pracy.';es_ES = 'Top 10 de los autores por el tiempo promedio de finalización de tarea.';es_CO = 'Top 10 de los autores por el tiempo promedio de finalización de tarea.';tr = 'Ortalama görev tamamlama süresine göre en iyi 10 yazar.';it = '10 principali autori per il velocità media di realizzazione dei compiti.';de = 'Top 10-Autoren nach durchschnittlicher Zeit von Arbeitserfüllung.'");
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#EndIf