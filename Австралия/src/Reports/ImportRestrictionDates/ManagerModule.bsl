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
	
	Reports.PeriodClosingDates.CustomizeForm(Form, FirstOption, SecondOption, Option);
	
EndProcedure

Function FirstOption()
	
	Try
		Properties = PeriodClosingDatesInternal.SectionsProperties();
	Except
		Properties = New Structure("ShowSections, AllSectionsWithoutObjects", False, True);
	EndTry;
	
	If Properties.ShowSections AND NOT Properties.AllSectionsWithoutObjects Then
		OptionName = "ImportRestrictionDatesByInfobases";
		
	ElsIf Properties.AllSectionsWithoutObjects Then
		OptionName = "ImportRestrictionDatesByInfobasesWithoutObjects";
	Else
		OptionName = "ImportRestrictionDatesByInfobasesWithoutSections";
	EndIf;
	
	OptionProperties = New Structure;
	OptionProperties.Insert("Name", OptionName);
	
	OptionProperties.Insert("Title",
		NStr("ru = 'Даты запрета загрузки данных по информационным базам'; en = 'Data import restriction dates by infobases'; pl = 'Data zakazu importu danych według baz informacyjnych';es_ES = 'Fecha de cierre de la importación de datos por infobases';es_CO = 'Fecha de cierre de la importación de datos por infobases';tr = 'Verilerin veri tabanlarından içe aktarılmasına kapatıldığı tarih';it = 'Restrizione importazione dati per infobases';de = 'Abschlussdatum des Datenimports durch Infobasen'"));
	
	OptionProperties.Insert("Details",
		NStr("ru = 'Выводит даты запрета загрузки для объектов, сгруппированные по информационным базам.'; en = 'Displays data import restriction dates for objects grouped by infobases.'; pl = 'Wyświetla daty zakazu pobierania obiektów, pogrupowanych według baz informacyjnych.';es_ES = 'Visualiza las fechas sin importar para los objetos agrupados por las bases de información.';es_CO = 'Visualiza las fechas sin importar para los objetos agrupados por las bases de información.';tr = 'Veri tabanlarına göre gruplandırılmış nesneler için içe aktarma tarihleri gösterir.';it = 'Visualizza le date di divieto del download per gli oggetti raggruppati per database.';de = 'Zeigt die Download-Verbotsdaten für Objekte an, die nach Informationsdatenbanken gruppiert sind.'"));
	
	Return OptionProperties;
	
EndFunction

Function SecondOption()
	
	Try
		Properties = PeriodClosingDatesInternal.SectionsProperties();
	Except
		Properties = New Structure("ShowSections, AllSectionsWithoutObjects", False, True);
	EndTry;
	
	If Properties.ShowSections AND NOT Properties.AllSectionsWithoutObjects Then
		OptionName = "ImportRestrictionDatesBySectionsObjectsForInfobases";
		Header = NStr("ru = 'Даты запрета загрузки данных по разделам и объектам'; en = 'Data import restriction dates by sections and objects'; pl = 'Daty zakazu pobierania danych według działów i obiektów';es_ES = 'Fechas de restricción de descargas de datos por secciones y objetos';es_CO = 'Fechas de restricción de descargas de datos por secciones y objetos';tr = 'Bölümlere ve nesnelere göre veri yüklenmesi için son tarih';it = 'Date di restrazione importazione dati per sezioni e oggetti';de = 'Daten zum Verbot des Datenladens nach Abschnitten und Objekten'");
		OptionDetails =
			NStr("ru = 'Выводит даты запрета загрузки, сгруппированные по разделам с объектами.'; en = 'Displays data import restriction dates grouped by sections with objects.'; pl = 'Wyświetla daty zakazu pobierania, pogrupowane według sekcji z obiektami.';es_ES = 'Visualiza las fechas sin importar para los usuarios agrupados por secciones con objetos.';es_CO = 'Visualiza las fechas sin importar para los usuarios agrupados por secciones con objetos.';tr = 'Nesnelerle bölümlere göre gruplandırılmış içe aktarma yasaklama tarihleri gösterir.';it = 'Visualizza le date di divieto del download raggruppate per sezioni con oggetti.';de = 'Zeigt die Download-Verbotsdaten gruppiert nach Objektbereichen an.'");
		
	ElsIf Properties.AllSectionsWithoutObjects Then
		OptionName = "ImportRestrictionDatesBySectionsForInfobases";
		Header = NStr("ru = 'Даты запрета загрузки данных по разделам'; en = 'Data import restriction dates by sections'; pl = 'Daty zakazu pobierania danych według działów';es_ES = 'Fechas de restricción de descargas de datos por secciones';es_CO = 'Fechas de restricción de descargas de datos por secciones';tr = 'Bölümlere göre veri yüklenmesi için son tarih';it = 'Date di restrazione importazione dati per sezioni';de = 'Verbotsdaten des Ladens von Daten nach Abschnitten'");
		OptionDetails =
			NStr("ru = 'Выводит даты запрета загрузки, сгруппированные по разделам.'; en = 'Displays data import restriction dates grouped by sections.'; pl = 'Wyświetla daty zakazu pobierania, pogrupowane według sekcji.';es_ES = 'Muestra las fechas de restricción de descargas agrupadas por secciones.';es_CO = 'Muestra las fechas de restricción de descargas agrupadas por secciones.';tr = 'Bölümlere göre gruplandırılmış içe aktarma yasaklama tarihleri gösterir.';it = 'Visualizza le date di divieto del download raggruppate per sezioni.';de = 'Zeigt die Download-Verbotsdaten nach Abschnitten gruppiert an.'");
	Else
		OptionName = "ImportRestrictionDatesByObjectsForInfobases";
		Header = NStr("ru = 'Даты запрета загрузки данных по объектам'; en = 'Data import restriction dates by objects'; pl = 'Daty zakazu pobierania danych według obiektów';es_ES = 'Fechas de restricción de descargas de datos por objetos';es_CO = 'Fechas de restricción de descargas de datos por objetos';tr = 'Nesnelere göre veri yüklenmesi için son tarih';it = 'Date di restrazione importazione dati per  oggetti';de = 'Verbotsdaten des Ladens von Daten nach Objekten'");
		OptionDetails =
			NStr("ru = 'Выводит даты запрета загрузки, сгруппированные по объектам.'; en = 'Displays data import restriction dates grouped by objects.'; pl = 'Wyświetla daty zakazu pobierania, pogrupowane według obiektów.';es_ES = 'Muestra las fechas de restricción de descargas agrupadas por objetos.';es_CO = 'Muestra las fechas de restricción de descargas agrupadas por objetos.';tr = 'Nesnelere göre gruplandırılmış içe aktarma yasaklama tarihleri gösterir.';it = 'Visualizza le date di divieto del download raggruppate per oggetti.';de = 'Zeigt die Download-Verbotsdaten nach Objekten gruppiert an.'");
	EndIf;
	
	OptionProperties = New Structure;
	OptionProperties.Insert("Name",       OptionName);
	OptionProperties.Insert("Title", Header);
	OptionProperties.Insert("Details",  OptionDetails);
	
	Return OptionProperties;
	
EndFunction

#EndRegion

#EndIf
