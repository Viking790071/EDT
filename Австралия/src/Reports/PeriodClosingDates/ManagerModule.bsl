#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.ReportsOptions

// See ReportsOptionsOverridable.CustomizeReportOptions. 
//
Procedure CustomizeReportOptions(Settings, ReportSettings) Export
	
	ModuleReportsOptions = Common.CommonModule("ReportsOptions");
	
	ReportSettings.DefineFormSettings = True;
	ReportSettings.Enabled = False;
	
	FirstOption = FirstOption();
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, FirstOption.Name);
	OptionSettings.Enabled  = True;
	OptionSettings.Details = FirstOption.Details;
	
	SecondOption = SecondOption();
	OptionSettings = ModuleReportsOptions.OptionDetails(Settings, ReportSettings, SecondOption.Name);
	OptionSettings.Enabled  = True;
	OptionSettings.Details = SecondOption.Details;
	
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#EndIf

#Region EventHandlers

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInfo, StandardProcessing)
	
	If FormType <> "Form" Then
		Return;
	EndIf;
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		Return;
	EndIf;
#Else
	If CommonClient.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		Return;
	EndIf;
#EndIf
	
	StandardProcessing = False;
	SelectedForm = "ReportForm";
	
EndProcedure

#EndRegion

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

// Called from the report form.
Procedure SetOption(Form, Option) Export
	
	FirstOption = FirstOption();
	SecondOption = SecondOption();
	
	CustomizeForm(Form, FirstOption, SecondOption, Option);
	
EndProcedure

// Calls the SetOption procedure.
Procedure CustomizeForm(Form, FirstOption, SecondOption, Option) Export
	
	Items = Form.Items;
	
	If Option = 0 Then
		Form.Parameters.GenerateOnOpen = True;
		Items.FormFirstOption.Title = FirstOption.Title;
		Items.FormSecondOption.Title = SecondOption.Title;
	Else
		ReportFullName = "Report." + StrSplit(Form.FormName, ".", False)[1];
		
		// Saving the current user settings.
		Common.SystemSettingsStorageSave(
			ReportFullName + "/" + Form.CurrentVariantKey + "/CurrentUserSettings",
			"",
			Form.Report.SettingsComposer.UserSettings);
	EndIf;
	
	If Option = 0 Then
		If Form.CurrentVariantKey = FirstOption.Name Then
			Option = 1;
		ElsIf Form.CurrentVariantKey = SecondOption.Name Then
			Option = 2;
		EndIf;
	EndIf;
	
	If Option = 0 Then
		Option = 1;
	EndIf;
	
	If Option = 1 Then
		Items.FormFirstOption.Check = True;
		Items.FormSecondOption.Check = False;
		Form.Title = FirstOption.Title;
		CurrentOptionKey = FirstOption.Name;
	Else
		Items.FormFirstOption.Check = False;
		Items.FormSecondOption.Check = True;
		Form.Title = SecondOption.Title;
		CurrentOptionKey = SecondOption.Name;
	EndIf;
	
	// Importing a new option.
	Form.SetCurrentVariant(CurrentOptionKey);
	
	// Regenerating the report.
	Form.ComposeResult(ResultCompositionMode.Auto);
	
EndProcedure

Function FirstOption()
	
	Try
		Properties = PeriodClosingDatesInternal.SectionsProperties();
	Except
		Properties = New Structure("ShowSections, AllSectionsWithoutObjects", False, True);
	EndTry;
	
	If Properties.ShowSections AND NOT Properties.AllSectionsWithoutObjects Then
		OptionName = "PeriodClosingDatesByUsers";
		
	ElsIf Properties.AllSectionsWithoutObjects Then
		OptionName = "PeriodClosingDatesByUsersWithoutObjects";
	Else
		OptionName = "PeriodClosingDatesByUsersWithoutSections";
	EndIf;
	
	OptionProperties = New Structure;
	OptionProperties.Insert("Name", OptionName);
	
	OptionProperties.Insert("Title",
		NStr("ru = 'Даты запрета изменения данных по пользователям'; en = 'Period-end closing dates by users'; pl = 'Daty zamknięcia według użytkowników';es_ES = 'Fechas de cierre por usuarios';es_CO = 'Fechas de cierre por usuarios';tr = 'Kullanıcılara göre dönem sonu kapanış tarihleri';it = 'Data di chiusura fine periodo per utenti';de = 'Sperrdaten von Benutzern'"));
	
	OptionProperties.Insert("Details",
		NStr("ru = 'Выводит даты запрета изменения, сгруппированные по пользователям.'; en = 'Displays period-end closing dates grouped by users.'; pl = 'Wyświetla daty zakazu zmian, pogrupowane według użytkowników.';es_ES = 'Muestra las fechas de restricción de cambio agrupadas por usuarios.';es_CO = 'Muestra las fechas de restricción de cambio agrupadas por usuarios.';tr = 'Kullanıcılara göre gruplandırılmış içe aktarma yasaklama tarihleri gösterir.';it = 'Mostra le date di chiusura fine periodo raggruppate per utenti.';de = 'Zeigt Änderungsverbotsdaten an, die nach Benutzern gruppiert sind.'"));
	
	Return OptionProperties;
	
EndFunction

Function SecondOption()
	
	Try
		Properties = PeriodClosingDatesInternal.SectionsProperties();
	Except
		Properties = New Structure("ShowSections, AllSectionsWithoutObjects", False, True);
	EndTry;
	
	If Properties.ShowSections AND NOT Properties.AllSectionsWithoutObjects Then
		OptionName = "PeriodClosingDatesBySectionsObjectsForUsers";
		Header = NStr("ru = 'Даты запрета изменения данных по разделам и объектам'; en = 'Period-end closing dates by sections and objects'; pl = 'Daty zakazu zmiany danych według działów i obiektów';es_ES = 'Fechas de restricción de cambio de datos por secciones y objetos';es_CO = 'Fechas de restricción de cambio de datos por secciones y objetos';tr = 'Bölümlere ve nesnelere göre veri değişikliği için son tarih';it = 'Data di chiusura fine periodo per sezioni e oggetti';de = 'Verbotsdaten zum Ändern von Daten nach Abschnitten und Objekten'");
		OptionDetails =
			NStr("ru = 'Выводит даты запрета изменения, сгруппированные по разделам с объектами.'; en = 'Displays period-end closing dates grouped by sections with objects.'; pl = 'Wyświetla daty zakazu zmian, pogrupowane według sekcji z obiektami.';es_ES = 'Muestra las fechas de restricción de cambio agrupadas por secciones y objetos.';es_CO = 'Muestra las fechas de restricción de cambio agrupadas por secciones y objetos.';tr = 'Nesnelerle bölümlere göre gruplandırılmış değişiklik yasaklama tarihleri gösterir.';it = 'Mostra le date di chiusura fine periodo raggruppate per sezioni con oggetti.';de = 'Zeigt Änderungsverbotsdaten an, die nach Abschnitten mit Objekten gruppiert sind.'");
		
	ElsIf Properties.AllSectionsWithoutObjects Then
		OptionName = "PeriodClosingDatesBySectionsForUsers";
		Header = NStr("ru = 'Даты запрета изменения данных по разделам'; en = 'Period-end closing dates by sections'; pl = 'Daty zakazu zmiany danych według działów';es_ES = 'Fechas de restricción de cambio de datos por secciones';es_CO = 'Fechas de restricción de cambio de datos por secciones';tr = 'Bölümlere göre veri değişikliği için son tarih';it = 'Data di chiusura fine periodo per sezioni';de = 'Verbotsdaten zum Ändern von Daten nach Abschnitten'");
		OptionDetails =
			NStr("ru = 'Выводит даты запрета изменения, сгруппированные по разделам.'; en = 'Displays period-end closing dates grouped by sections.'; pl = 'Wyświetla daty zakazu zmian, pogrupowane według sekcji.';es_ES = 'Muestra las fechas de restricción de cambio agrupadas por secciones.';es_CO = 'Muestra las fechas de restricción de cambio agrupadas por secciones.';tr = 'Bölümlere göre gruplandırılmış değişiklik yasaklama tarihleri gösterir.';it = 'Mostra le date di chiusura fine periodo raggruppate per sezioni.';de = 'Zeigt Änderungsverbotsdaten an, die nach Abschnitten gruppiert sind.'");
	Else
		OptionName = "PeriodClosingDatesByObjectsForUsers";
		Header = NStr("ru = 'Даты запрета изменения данных по объектам'; en = 'Period-end closing dates by objects'; pl = 'Daty zakazu zmian danych według obiektów';es_ES = 'Fechas de restricción de cambio de datos por objetos';es_CO = 'Fechas de restricción de cambio de datos por objetos';tr = 'Nesnelere göre veri değişikliği için son tarih';it = 'Data di chiusura fine periodo per oggetti';de = 'Verbotsdaten zum Ändern von Daten nach Objekten'");
		OptionDetails =
			NStr("ru = 'Выводит даты запрета изменения, сгруппированные по объектам.'; en = 'Displays period-end closing dates grouped by objects.'; pl = 'Wyświetla daty zakazu zmian, pogrupowane według obiektów.';es_ES = 'Muestra las fechas de restricción de cambio agrupadas por objetos.';es_CO = 'Muestra las fechas de restricción de cambio agrupadas por objetos.';tr = 'Nesnelere göre gruplandırılmış değişiklik yasaklama tarihleri gösterir.';it = 'Mostra le date di chiusura fine periodo raggruppate per oggetti.';de = 'Zeigt Änderungsverbotsdaten an, die nach Objekten gruppiert sind.'");
	EndIf;
	
	OptionProperties = New Structure;
	OptionProperties.Insert("Name",       OptionName);
	OptionProperties.Insert("Title", Header);
	OptionProperties.Insert("Details",  OptionDetails);
	
	Return OptionProperties;
	
EndFunction

#EndRegion

#EndIf
