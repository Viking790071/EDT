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
	ReportSettings.Details = NStr("ru = 'Список и сводная статистика по задачам.'; en = 'Task list and summary.'; pl = 'Lista zadań i podsumowanie.';es_ES = 'Lista de tareas y resumen.';es_CO = 'Lista de tareas y resumen.';tr = 'Görev listesi ve özet.';it = 'Elenco e statistiche riassuntive sulle attività.';de = 'Aufgabenliste und Bericht.'");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "CurrentTasks");
	OptionSettings.Details = NStr("ru = 'Список всех задач в работе к заданному сроку.'; en = 'All tasks in progress by the specified due date.'; pl = 'Wszystkie zadania w toku w określonym terminie.';es_ES = 'Todas las tareas en curso en la fecha de vencimiento especificada.';es_CO = 'Todas las tareas en curso en la fecha de vencimiento especificada.';tr = 'Belirtilen bitiş tarihine kadar devam eden tüm görevler.';it = 'Un elenco di tutte le attività nel lavoro ad una determinata data.';de = 'Alle Aufgaben in Bearbeitung bis zum angegebenen Termin.'");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "PerformerDisciplineSummary");
	OptionSettings.Details = NStr("ru = 'Сводка по количеству выполненных в срок и просроченных задачах у исполнителей.'; en = 'Overdue tasks and tasks completed on schedule summary by assignee.'; pl = 'Zaległe zadania i zadania zakończone zgodnie z harmonogramem przez wykonawcę.';es_ES = 'Tareas atrasadas y tareas completadas según el resumen del calendario por el ejecutor';es_CO = 'Tareas atrasadas y tareas completadas según el resumen del calendario por el ejecutor';tr = 'Vadesi geçmiş görevler ve vaktinde tamamlanmış görevlerin atanana göre özeti';it = 'Riepilogo del numero di attività completate e attività scadute degli esecutori.';de = 'Bericht über überfällige und rechtzeitig erfüllte Aufgaben bezogen auf Bevollmächtiger.'");
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#EndIf