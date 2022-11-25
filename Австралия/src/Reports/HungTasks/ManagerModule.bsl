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
	ReportSettings.Details = NStr("ru = 'Анализ зависших задач, которые не могут быть выполнены, так как у них не назначены исполнители.'; en = 'Unassigned tasks analysis (tasks not assigned to any users).'; pl = 'Analiza nieprzypisanych zadań (zadania nie przypisane żadnemu użytkownikowi).';es_ES = 'Análisis de tareas no asignadas (tareas no asignadas a ningún usuario).';es_CO = 'Análisis de tareas no asignadas (tareas no asignadas a ningún usuario).';tr = 'Atanmayan görevler analizi (hiçbir kullanıcın atanmadığı görevler).';it = 'Analisi delle attività bloccate che non possono essere eseguite, perché non non sono state loro assegnati degli esecutori.';de = 'Analyse von nicht zugeordneten Aufgaben (keinen Benutzern zugeordnete Aufgaben).'");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "UnassignedTasksSummary");
	OptionSettings.Details = NStr("ru = 'Сводка по количеству зависших задач, назначенных на роли, для которых не задано ни одного исполнителя.'; en = 'Unassigned tasks summary (tasks assigned to blank roles).'; pl = 'Podsumowanie nieprzypisanych zadań (zadania przypisane do pustych roli).';es_ES = 'Resumen de las tareas no asignadas (tareas asignadas a roles en blanco).';es_CO = 'Resumen de las tareas no asignadas (tareas asignadas a roles en blanco).';tr = 'Atanmayan görevler toplamı (boş rollere atanan görevler).';it = 'Riepilogo del numero di obiettivi bloccati assegnati ai ruoli per i quali non è stato assegnato alcun esecutore.';de = 'Bericht von nicht zugeordneten Aufgaben (Aufgaben zugeordnet zu blinden Rollen).'");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "UnassignedTasksByPerformers");
	OptionSettings.Details = NStr("ru = 'Список зависших задач, назначенных на роли, для которых не задано ни одного исполнителя.'; en = 'Unassigned tasks (tasks assigned to blank roles).'; pl = 'Nieprzypisane zadania (zadania przypisane do pustych roli).';es_ES = 'Tareas no asignadas  (tareas asignadas a roles en blanco).';es_CO = 'Tareas no asignadas  (tareas asignadas a roles en blanco).';tr = 'Atanmayan görevler (boş rollere atanan görevler).';it = 'Elenco delle attività bloccate assegnate ai ruoli per i quali non è specificato alcun esecutore.';de = 'Nicht zugeordnete Aufgaben (Aufgaben zugeordnet zu blinden Rollen).'");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "UnassignedTasksByAddressingObjects");
	OptionSettings.Details = NStr("ru = 'Список зависших задач по объектам адресации.'; en = 'Unassigned tasks by addressing objects.'; pl = 'Nieprzypisane zadanie według obiektów adresacji.';es_ES = 'Tareas no asignadas por objetos de direccionamiento.';es_CO = 'Tareas no asignadas por objetos de direccionamiento.';tr = 'Gönderim hedefine göre atanmamış görevler.';it = 'Task non assegnati per oggetti di indirizzamento.';de = 'Nicht zugeordnete Aufgaben nach Objekten von Adressierung'");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "OverdueTasks");
	OptionSettings.Details = NStr("ru = 'Список просроченных и зависших задач, которые не могут быть выполнены, так как у них не назначены исполнители.'; en = 'Unassigned and overdue tasks (tasks not assigned to any users).'; pl = 'Nieprzypisane i zaległe zadania (zadania nie przypisane żadnemu użytkownikowi).';es_ES = 'Tareas no asignadas y atrasadas (tareas no asignadas a ningún usuario).';es_CO = 'Tareas no asignadas y atrasadas (tareas no asignadas a ningún usuario).';tr = 'Atanmayan ve vadesi geçmiş görevler (hiçbir kullanıcının atanmadığı görevler).';it = 'Elenco delle attività bloccate che non possono essere eseguite, perché non non sono state loro assegnati degli esecutori.';de = 'Nicht zugeordnete und überfällige Aufgaben (keinen Benutzern zugeordnete Aufgaben).'");
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#EndIf