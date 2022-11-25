#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.ReportsOptions

// The settings of the common report form of the "Reports options" subsystem.
//
// Parameters:
//   Form - ClientApplicationForm, Undefined - a report form or a report settings form.
//       Undefined when called without a context.
//   OptionKey - String, Undefined - a name of a predefined report option or a UUID of a 
//       user-defined report option.
//       Undefined when called without a context.
//   Settings - Structure - see the return value of
//       ReportsClientServer.GetDefaultReportSettings().
//
Procedure DefineFormSettings(Form, OptionKey, Settings) Export
	
	Settings.GenerateImmediately = True;
	
	If Form <> Undefined Then
		SetPredefinedByImplementationOption(Form, OptionKey);
	EndIf;
	
EndProcedure

// End StandardSubsystems.ReportsOptions

#EndRegion

#EndRegion

#Region EventHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	StandardProcessing = False;
	
	ResultDocument.Clear();
	
	Settings = SettingsComposer.GetSettings();
	
	ExternalDataSets = New Structure;
	ExternalDataSets.Insert("DataSet", ClosingDatesPrepared(Settings.DataParameters));
	
	TemplateComposer = New DataCompositionTemplateComposer;
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, Settings, DetailsData);
	
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, ExternalDataSets, DetailsData, True);
	
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);
	
	OutputProcessor.BeginOutput();
	ResultItem = CompositionProcessor.Next();
	While ResultItem <> Undefined Do
		OutputProcessor.OutputItem(ResultItem);
		ResultItem = CompositionProcessor.Next();
	EndDo;
	OutputProcessor.EndOutput();
	
EndProcedure

#EndRegion

#Region Private

Procedure SetPredefinedByImplementationOption(Form, OptionKey)
	
	If Form.Parameters.VariantKey <> Undefined Then
		Return; // Report option is specified upon opening.
	EndIf;
	
	Try
		Properties = PeriodClosingDatesInternal.SectionsProperties();
	Except
		Properties = New Structure("ShowSections, AllSectionsWithoutObjects", False, True);
	EndTry;
	
	If Properties.ShowSections AND NOT Properties.AllSectionsWithoutObjects Then
		
		If OptionKey <> "ImportRestrictionDatesByInfobases"
		   AND OptionKey <> "ImportRestrictionDatesBySectionsObjectsForInfobases" Then
			
			Form.Parameters.VariantKey = "ImportRestrictionDatesByInfobases";
		EndIf;
		
	ElsIf Properties.AllSectionsWithoutObjects Then
		
		If OptionKey <> "ImportRestrictionDatesByInfobasesWithoutObjects"
		   AND OptionKey <> "ImportRestrictionDatesBySectionsForInfobases" Then
			
			Form.Parameters.VariantKey = "ImportRestrictionDatesByInfobasesWithoutObjects";
		EndIf;
	Else
		If OptionKey <> "ImportRestrictionDatesByInfobasesWithoutSections"
		   AND OptionKey <> "ImportRestrictionDatesByObjectsForInfobases" Then
			
			Form.Parameters.VariantKey = "ImportRestrictionDatesByInfobasesWithoutSections";
		EndIf;
	EndIf;
	
EndProcedure

Function ClosingDatesPrepared(DataParameters)
	
	Query = New Query;
	Query.Text = QueryText();
	Query.SetParameter("SpecifiedRecipients",     UserParameterValue(DataParameters, "Recipients"));
	Query.SetParameter("SpecifiedSections",      UserParameterValue(DataParameters, "Sections"));
	Query.SetParameter("SpecifiedObjects",      UserParameterValue(DataParameters, "Objects"));
	Query.SetParameter("PeriodClosingDates", PeriodClosingDatesInternal.CalculatedPeriodClosingDates());
	
	Table = Query.Execute().Unload();
	Table.Columns.Add("ObjectPresentation",            New TypeDescription("String"));
	Table.Columns.Add("SectionPresentation",            New TypeDescription("String"));
	Table.Columns.Add("SettingsRecipientPresentation",  New TypeDescription("String"));
	Table.Columns.Add("SettingsOwnerPresentation", New TypeDescription("String"));
	Table.Columns.Add("CommonDateSetting",             New TypeDescription("Boolean"));
	Table.Columns.Add("SettingForSection",            New TypeDescription("Boolean"));
	Table.Columns.Add("SettingForAllRecipients",      New TypeDescription("Boolean"));
	
	For Each Row In Table Do
		
		If Row.Object <> Row.Section Then
			Row.ObjectPresentation = String(Row.Object);
			
		ElsIf ValueIsFilled(Row.Section) Then
			Row.ObjectPresentation = NStr("ru = 'Для всех объектов, кроме указанных'; en = 'For all objects except for the specified ones'; pl = 'Dla wszystkich obiektów, z wyjątkiem wskazanych';es_ES = 'Para todos los objetos a excepción de los especificados';es_CO = 'Para todos los objetos a excepción de los especificados';tr = 'Belirtilenlerin dışında tüm nesneler için';it = 'Per tutti gli oggetti tranne quelli specificati';de = 'Für alle Objekte außer den angegebenen'");
		Else
			Row.ObjectPresentation = NStr("ru = 'Для всех разделов и объектов, кроме указанных'; en = 'For all sections and objects except for the specified ones'; pl = 'Dla wszystkich sekcji i obiektów, z wyjątkiem wskazanych';es_ES = 'Para todos los secciones y objetos a excepción de los especificados';es_CO = 'Para todos los secciones y objetos a excepción de los especificados';tr = 'Belirtilenlerin dışında tüm bölümler ve nesneler için';it = 'Per tutte le sezioni e oggetti tranne quelli specificati';de = 'Für alle Abschnitte und Objekte außer den angegebenen'");
		EndIf;
		
		If ValueIsFilled(Row.Section) Then
			Row.SectionPresentation = String(Row.Section);
		Else
			Row.SectionPresentation = "<" + NStr("ru = 'Общая дата'; en = 'Common date'; pl = 'Wspólna data';es_ES = 'Fecha común';es_CO = 'Fecha común';tr = 'Ortak tarih';it = 'Data comune';de = 'Gemeinsame Datum'") + ">";
		EndIf;
		
		If Row.SettingsRecipient = Enums.PeriodClosingDatesPurposeTypes.ForAllInfobases Then
			Row.SettingsRecipientPresentation = NStr("ru = 'Для всех информационных баз, кроме указанных'; en = 'For all infobases except for the specified ones'; pl = 'Dla wszystkich baz informacyjnych, z wyjątkiem wskazanych';es_ES = 'Para todas las infobases a excepción de las especificadas';es_CO = 'Para todas las infobases a excepción de las especificadas';tr = 'Belirtilenlerin dışında tüm veritabanları için';it = 'Per tutti gli infobase tranne quelli specificati';de = 'Für alle Informationsbasen außer den angegebenen'");
		Else
			Row.SettingsRecipientPresentation = String(TypeOf(Row.SettingsRecipient)) + ":"
				+ ?(ValueIsFilled(Row.SettingsRecipient),
					String(Row.SettingsRecipient),
					NStr("ru = 'Все информационные базы'; en = 'All infobases'; pl = 'Wszystkie bazy informacyjne';es_ES = 'Todas las bases de información';es_CO = 'Todas las bases de información';tr = 'Tüm veri tabanları';it = 'Tutti gli infobase';de = 'Alle Informationsbasen'"));
		EndIf;
		
		If Row.SettingsOwner = Enums.PeriodClosingDatesPurposeTypes.ForAllInfobases Then
			Row.SettingsOwnerPresentation = NStr("ru = 'Для всех информационных баз, кроме указанных'; en = 'For all infobases except for the specified ones'; pl = 'Dla wszystkich baz informacyjnych, z wyjątkiem wskazanych';es_ES = 'Para todas las infobases a excepción de las especificadas';es_CO = 'Para todas las infobases a excepción de las especificadas';tr = 'Belirtilenlerin dışında tüm veritabanları için';it = 'Per tutti gli infobase tranne quelli specificati';de = 'Für alle Informationsbasen außer den angegebenen'");
		Else
			Row.SettingsOwnerPresentation = String(TypeOf(Row.SettingsOwner)) + ":"
				+ ?(ValueIsFilled(Row.SettingsOwner),
					String(Row.SettingsOwner),
					NStr("ru = 'Все информационные базы'; en = 'All infobases'; pl = 'Wszystkie bazy informacyjne';es_ES = 'Todas las bases de información';es_CO = 'Todas las bases de información';tr = 'Tüm veri tabanları';it = 'Tutti gli infobase';de = 'Alle Informationsbasen'"));
		EndIf;
		
		Row.CommonDateSetting  = Not ValueIsFilled(Row.Section);
		Row.SettingForSection = Row.Object = Row.Section;
		Row.SettingForAllRecipients =
			Row.SettingsRecipient = Enums.PeriodClosingDatesPurposeTypes.ForAllInfobases;
	EndDo;
	
	Return Table;
	
EndFunction

Function UserParameterValue(DataParameters, ParameterName)
	
	Parameter = DataParameters.FindParameterValue(New DataCompositionParameter(ParameterName));
	
	If Not Parameter.Use Then
		Return False;
	EndIf;
	
	If TypeOf(Parameter.Value) = Type("ValueList") Then
		Return Parameter.Value.UnloadValues();
	EndIf;
	
	Array = New Array;
	Array.Add(Parameter.Value);
	
	Return Array;
	
EndFunction

Function QueryText()
	
	Return
	"SELECT
	|	PeriodClosingDates.Section AS Section,
	|	PeriodClosingDates.Object AS Object,
	|	PeriodClosingDates.User AS User,
	|	PeriodClosingDates.PeriodEndClosingDate AS PeriodEndClosingDate,
	|	PeriodClosingDates.Comment AS Comment
	|INTO PeriodClosingDates
	|FROM
	|	&PeriodClosingDates AS PeriodClosingDates
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ConfiguredUsersWithGroups.User AS User,
	|	PeriodClosingDates.User AS SettingsOwner,
	|	PeriodClosingDates.Section AS Section,
	|	PeriodClosingDates.Object AS Object,
	|	PeriodClosingDates.PeriodEndClosingDate AS PeriodEndClosingDate,
	|	PriorityCodes.Value AS Priority
	|INTO ClosingDates
	|FROM
	|	PeriodClosingDates AS PeriodClosingDates
	|		INNER JOIN (SELECT
	|			0 AS Code,
	|			1 AS Value
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			1,
	|			2
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			10,
	|			3
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			1000,
	|			4
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			1001,
	|			5
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			1010,
	|			6
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			1100,
	|			7
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			1101,
	|			8
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			1110,
	|			9) AS PriorityCodes
	|		ON (CASE
	|				WHEN PeriodClosingDates.User = VALUE(Enum.PeriodClosingDatesPurposeTypes.ForAllInfobases)
	|					THEN 0
	|				ELSE 10
	|			END + CASE
	|				WHEN PeriodClosingDates.Object = PeriodClosingDates.Section
	|					THEN 0
	|				ELSE 100
	|			END + CASE
	|				WHEN PeriodClosingDates.Section = VALUE(ChartOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef)
	|					THEN 0
	|				ELSE 1000
	|			END = PriorityCodes.Code)
	|		INNER JOIN (SELECT
	|			PeriodClosingDates.User AS User,
	|			PeriodClosingDates.User AS UsersGroup
	|		FROM
	|			PeriodClosingDates AS PeriodClosingDates
	|		WHERE
	|			VALUETYPE(PeriodClosingDates.User) <> TYPE(Catalog.Users)
	|			AND VALUETYPE(PeriodClosingDates.User) <> TYPE(Catalog.UserGroups)
	|			AND VALUETYPE(PeriodClosingDates.User) <> TYPE(Catalog.ExternalUsers)
	|			AND VALUETYPE(PeriodClosingDates.User) <> TYPE(Catalog.ExternalUsersGroups)
	|			AND PeriodClosingDates.User <> VALUE(Enum.PeriodClosingDatesPurposeTypes.ForAllUsers)
	|			AND (FALSE IN (&SpecifiedRecipients)
	|					OR PeriodClosingDates.User IN (&SpecifiedRecipients))
	|		
	|		UNION
	|		
	|		SELECT
	|			VALUE(Enum.PeriodClosingDatesPurposeTypes.ForAllInfobases),
	|			VALUE(Enum.PeriodClosingDatesPurposeTypes.ForAllInfobases)
	|		WHERE
	|			(FALSE IN (&SpecifiedRecipients)
	|					OR TRUE IN (&SpecifiedRecipients))) AS ConfiguredUsersWithGroups
	|		ON (PeriodClosingDates.User IN (VALUE(Enum.PeriodClosingDatesPurposeTypes.ForAllInfobases), ConfiguredUsersWithGroups.UsersGroup))
	|			AND (PeriodClosingDates.Object <> UNDEFINED)
	|			AND (NOT(PeriodClosingDates.Object <> PeriodClosingDates.Section
	|					AND PeriodClosingDates.Section = VALUE(ChartOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef)))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ClosingDates.User AS SettingsRecipient,
	|	ClosingDates.SettingsOwner AS SettingsOwner,
	|	ClosingDates.Section AS Section,
	|	ClosingDates.Object AS Object,
	|	PriorityDatesWithExclusionReasons.PeriodEndClosingDate AS PeriodEndClosingDate,
	|	ClosingDates.PeriodEndClosingDate AS PeriodEndClosingDateSettings,
	|	ClosingDates.Priority AS SettingsPriority,
	|	PeriodClosingDates.Comment AS SettingComment,
	|	PriorityDatesWithExclusionReasons.Comment AS Comment
	|FROM
	|	ClosingDates AS ClosingDates
	|		INNER JOIN (SELECT
	|			PriorityDates.User AS User,
	|			PriorityDates.Section AS Section,
	|			PriorityDates.Object AS Object,
	|			PriorityDates.PeriodEndClosingDate AS PeriodEndClosingDate,
	|			MAX(PeriodClosingDates.Comment) AS Comment
	|		FROM
	|			(SELECT
	|				ClosingDates.User AS User,
	|				ClosingDates.Section AS Section,
	|				ClosingDates.Object AS Object,
	|				MAX(ClosingDates.PeriodEndClosingDate) AS PeriodEndClosingDate,
	|				MAX(ClosingDates.Priority) AS Priority
	|			FROM
	|				ClosingDates AS ClosingDates
	|					INNER JOIN (SELECT
	|						ClosingDates.User AS User,
	|						ClosingDates.Section AS Section,
	|						ClosingDates.Object AS Object,
	|						MAX(ClosingDates.Priority) AS Priority
	|					FROM
	|						ClosingDates AS ClosingDates
	|					
	|					GROUP BY
	|						ClosingDates.User,
	|						ClosingDates.Section,
	|						ClosingDates.Object) AS MaxPriority
	|					ON ClosingDates.User = MaxPriority.User
	|						AND ClosingDates.Section = MaxPriority.Section
	|						AND ClosingDates.Object = MaxPriority.Object
	|						AND ClosingDates.Priority = MaxPriority.Priority
	|			
	|			GROUP BY
	|				ClosingDates.User,
	|				ClosingDates.Section,
	|				ClosingDates.Object) AS PriorityDates
	|				INNER JOIN ClosingDates AS ClosingDates
	|				ON (ClosingDates.User = PriorityDates.User)
	|					AND (ClosingDates.Section = PriorityDates.Section)
	|					AND (ClosingDates.Object = PriorityDates.Object)
	|					AND (ClosingDates.Priority = PriorityDates.Priority)
	|					AND (ClosingDates.PeriodEndClosingDate = PriorityDates.PeriodEndClosingDate)
	|				INNER JOIN PeriodClosingDates AS PeriodClosingDates
	|				ON (ClosingDates.SettingsOwner = PeriodClosingDates.User)
	|					AND (ClosingDates.Section = PeriodClosingDates.Section)
	|					AND (ClosingDates.Object = PeriodClosingDates.Object)
	|					AND (ClosingDates.PeriodEndClosingDate = PeriodClosingDates.PeriodEndClosingDate)
	|		
	|		GROUP BY
	|			PriorityDates.User,
	|			PriorityDates.Section,
	|			PriorityDates.Object,
	|			PriorityDates.Priority,
	|			PriorityDates.PeriodEndClosingDate) AS PriorityDatesWithExclusionReasons
	|		ON ClosingDates.User = PriorityDatesWithExclusionReasons.User
	|			AND ClosingDates.Section = PriorityDatesWithExclusionReasons.Section
	|			AND ClosingDates.Object = PriorityDatesWithExclusionReasons.Object
	|		INNER JOIN PeriodClosingDates AS PeriodClosingDates
	|		ON ClosingDates.SettingsOwner = PeriodClosingDates.User
	|			AND ClosingDates.Section = PeriodClosingDates.Section
	|			AND ClosingDates.Object = PeriodClosingDates.Object
	|WHERE
	|	(FALSE IN (&SpecifiedSections)
	|			OR ClosingDates.Section = VALUE(ChartOfCharacteristicTypes.PeriodClosingDatesSections.EmptyRef)
	|			OR ClosingDates.Section IN (&SpecifiedSections))
	|	AND (FALSE IN (&SpecifiedObjects)
	|			OR ClosingDates.Object = ClosingDates.Section
	|			OR ClosingDates.Object IN (&SpecifiedObjects))";
	
EndFunction

#EndRegion

#EndIf