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
	ReportSettings.Details = NStr("ru = 'Список задач, которые должны быть выполнены к указанной дате.'; en = 'Tasks that must be completed by the specified due date.'; pl = 'Zadania, które muszą być zakończone przed określonym terminem.';es_ES = 'Tareas que deben completarse en la fecha de vencimiento especificada.';es_CO = 'Tareas que deben completarse en la fecha de vencimiento especificada.';tr = 'Belirtilen bitiş tarihine kadar tamamlanması gereken görevler.';it = 'Elenco delle attività che devono essere completate entro la data specificata.';de = 'Aufgaben zur Erfüllung bis zum angegebenen Termin.'");
	
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, "ExpiringTasksOnDate");
	OptionSettings.Details = NStr("ru = 'Список задач, которые должны быть выполнены к указанной дате.'; en = 'Tasks that must be completed by the specified due date.'; pl = 'Zadania, które muszą być zakończone przed określonym terminem.';es_ES = 'Tareas que deben completarse en la fecha de vencimiento especificada.';es_CO = 'Tareas que deben completarse en la fecha de vencimiento especificada.';tr = 'Belirtilen bitiş tarihine kadar tamamlanması gereken görevler.';it = 'Elenco delle attività che devono essere completate entro la data specificata.';de = 'Aufgaben zur Erfüllung bis zum angegebenen Termin.'");
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#EndIf