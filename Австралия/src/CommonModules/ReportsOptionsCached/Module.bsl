#Region Internal

// Generates a list of configuration reports available for the current user.
// Use it in all queries to the table of the "ReportsOptions" catalog as a filter for the "Report" 
// attribute.
//
// Returns:
//   Array - references to reports the current user can access.
//            See the item type in the Catalogs.ReportOptions.Attributes.Report.
//
Function AvailableReports(CheckFunctionalOptions = True) Export
	Result = New Array;
	FullReportsNames = New Array;
	
	AllAttachedByDefault = Undefined;
	For Each ReportMetadata In Metadata.Reports Do
		If Not AccessRight("View", ReportMetadata)
			Or Not ReportsOptions.ReportAttachedToStorage(ReportMetadata, AllAttachedByDefault) Then
			Continue;
		EndIf;
		If CheckFunctionalOptions
			AND Not Common.MetadataObjectAvailableByFunctionalOptions(ReportMetadata) Then
			Continue;
		EndIf;
		FullReportsNames.Add(ReportMetadata.FullName());
	EndDo;
	
	ReportsIDs = Common.MetadataObjectIDs(FullReportsNames);
	For Each ReportID In ReportsIDs Do
		Result.Add(ReportID.Value);
	EndDo;
	
	Return New FixedArray(Result);
EndFunction

// Generates a list of configuration report option unavailable for the current user by functional options.
// Use in all queries to the table of the "ReportsOptions" catalog as an excluding filter for the 
// "PredefinedOption" attribute.
//
// Returns:
//   Array - report options that are disabled by functional options.
//            Item type - CatalogRef.PredefinedReportOptions,
//            CatalogRef.PredefinedReportOptionsOfExtensions.
//
Function DIsabledApplicationOptions() Export
	Return New FixedArray(ReportsOptions.DisabledReportOptions());
EndFunction

#EndRegion

#Region Private

// Generates a tree of subsystems available for the current user.
//
// Returns:
//   Result - ValueTree -
//       * SectionRef - CatalogRef.MetadataObjectIDs - a section reference.
//       * Ref       - CatalogRef.MetadataObjectIDs - a subsystem reference.
//       * Name           - String - a subsystem name.
//       * FullName     - String - the full name of the subsystem.
//       * Presentation - String - a subsystem presentation.
//       * Priority     - String - a subsystem priority.
//
Function CurrentUserSubsystems() Export
	
	IDTypesDetails = New TypeDescription;
	IDTypesDetails.Types().Add("CatalogRef.MetadataObjectIDs");
	IDTypesDetails.Types().Add("CatalogRef.ExtensionObjectIDs");
	
	Result = New ValueTree;
	Result.Columns.Add("Ref",              IDTypesDetails);
	Result.Columns.Add("Name",                 ReportsOptions.TypesDetailsString(150));
	Result.Columns.Add("FullName",           ReportsOptions.TypesDetailsString(510));
	Result.Columns.Add("Presentation",       ReportsOptions.TypesDetailsString(150));
	Result.Columns.Add("SectionRef",        IDTypesDetails);
	Result.Columns.Add("SectionFullName",     ReportsOptions.TypesDetailsString(510));
	Result.Columns.Add("Priority",           ReportsOptions.TypesDetailsString(100));
	Result.Columns.Add("FullPresentation", ReportsOptions.TypesDetailsString(300));
	
	RootRow = Result.Rows.Add();
	RootRow.Ref = Catalogs.MetadataObjectIDs.EmptyRef();
	RootRow.Presentation = NStr("ru = 'Все разделы'; en = 'All sections'; pl = 'Wszystkie sekcje';es_ES = 'Todas secciones';es_CO = 'Todas secciones';tr = 'Tüm bölümler';it = 'Tutte le sezioni';de = 'Alle Abschnitte'");
	
	FullNamesArray = New Array;
	TreeRowsFullNames = New Map;
	
	HomePageID = ReportsOptionsClientServer.HomePageID();
	SectionsList = ReportsOptions.SectionsList();
	
	Priority = 0;
	For Each ListItem In SectionsList Do
		
		MetadataSection = ListItem.Value;
		If NOT (TypeOf(MetadataSection) = Type("MetadataObject") AND StrStartsWith(MetadataSection.FullName(), "Subsystem"))
			AND NOT (TypeOf(MetadataSection) = Type("String") AND MetadataSection = HomePageID) Then
			
			Raise NStr("ru='Некорректно определены значения разделов в процедуре ReportOptionsOverridable.DefineSectionsWithReportOptions'; en = 'Section values in the ReportOptionsOverridable.DefineSectionsWithReportOptions procedure are defined incorrectly.'; pl = 'Wartości rozdziałów w ReportOptionsOverridable.DefineSectionsWithReportOptions procedurze są określone niepoprawnie.';es_ES = 'Los valores de secciones en el procedimiento ReportOptionsOverridable.DefineSectionsWithReportOptions están determinados incorrectamente';es_CO = 'Los valores de secciones en el procedimiento ReportOptionsOverridable.DefineSectionsWithReportOptions están determinados incorrectamente';tr = 'ReportOptionsOverridable.DefineSectionsWithReportOptions prosedüründeki bölüm değerleri yanlış tanımlanmıştır.';it = 'I valori delle sezioni nella procedura ReportOptionsOverridable.DefineSectionsWithReportOptions sono definiti in modo errato.';de = 'Die Werte von Abschnitten sind in der Prozedur ReportOptionsOverridable.DefineSectionsWithReportOptions.'");
			
		EndIf;
		
		If ValueIsFilled(ListItem.Presentation) Then
			CaptionPattern = ListItem.Presentation;
		Else
			CaptionPattern = NStr("ru = 'Отчеты раздела ""%1""'; en = '""%1"" reports'; pl = 'Sprawozdania ""%1""';es_ES = 'Informes ""%1""';es_CO = 'Informes ""%1""';tr = '""%1"" raporlar';it = 'Sezione report ""%1""';de = 'Berichte von ""%1""'");
		EndIf;
		IsHomePage = (MetadataSection = HomePageID);
		
		If Not IsHomePage
			AND (Not AccessRight("View", MetadataSection)
				Or Not Common.MetadataObjectAvailableByFunctionalOptions(MetadataSection)) Then
			Continue; // The subsystem is unavailable by FR or by rights.
		EndIf;
		
		TreeRow = RootRow.Rows.Add();
		If IsHomePage Then
			TreeRow.Name           = HomePageID;
			TreeRow.FullName     = HomePageID;
			TreeRow.Presentation = NStr("ru = 'Начальная страница'; en = 'Home page'; pl = 'Strona początkowa';es_ES = 'Página principal';es_CO = 'Página principal';tr = 'Ana sayfa';it = 'Pagina iniziale';de = 'Startseite'");
		Else
			TreeRow.Name           = MetadataSection.Name;
			TreeRow.FullName     = MetadataSection.FullName();
			TreeRow.Presentation = MetadataSection.Presentation();
		EndIf;
		FullNamesArray.Add(TreeRow.FullName);
		If TreeRowsFullNames[TreeRow.FullName] = Undefined Then
			TreeRowsFullNames.Insert(TreeRow.FullName, TreeRow);
		Else
			TreeRowsFullNames.Insert(TreeRow.FullName, True); // A search in the tree is required.
		EndIf;
		TreeRow.SectionFullName = TreeRow.FullName;
		TreeRow.FullPresentation = StringFunctionsClientServer.SubstituteParametersToString(
			CaptionPattern,
			TreeRow.Presentation);
		
		Priority = Priority + 1;
		TreeRow.Priority = Format(Priority, "ND=4; NFD=0; NLZ=; NG=0");
		If Not IsHomePage Then
			AddCurrentUserSubsystems(TreeRow, MetadataSection, FullNamesArray, TreeRowsFullNames);
		EndIf;
	EndDo;
	
	SubsystemsReferences = Common.MetadataObjectIDs(FullNamesArray);
	For Each KeyAndValue In SubsystemsReferences Do
		TreeRow = TreeRowsFullNames[KeyAndValue.Key];
		If TreeRow = True Then // A search in the tree is required.
			FoundItems = Result.Rows.FindRows(New Structure("FullName", KeyAndValue.Key), True);
			For Each TreeRow In FoundItems Do
				TreeRow.Ref = KeyAndValue.Value;
				TreeRow.SectionRef = SubsystemsReferences[TreeRow.SectionFullName];
			EndDo;
		Else
			TreeRow.Ref = KeyAndValue.Value;
			TreeRow.SectionRef = SubsystemsReferences[TreeRow.SectionFullName];
		EndIf;
	EndDo;
	TreeRowsFullNames.Clear();
	
	Return Result;
EndFunction

// Adds parent subsystems with a filter by access rights and functional options.
Procedure AddCurrentUserSubsystems(ParentLevelRow, ParentMetadata, FullNamesArray, TreeRowsFullNames)
	ParentPriority = ParentLevelRow.Priority;
	
	Priority = 0;
	For Each SubsystemMetadata In ParentMetadata.Subsystems Do
		Priority = Priority + 1;
		
		If Not SubsystemMetadata.IncludeInCommandInterface
			Or Not AccessRight("View", SubsystemMetadata)
			Or Not Common.MetadataObjectAvailableByFunctionalOptions(SubsystemMetadata) Then
			Continue; // The subsystem is unavailable by FR or by rights.
		EndIf;
		
		TreeRow = ParentLevelRow.Rows.Add();
		TreeRow.Name           = SubsystemMetadata.Name;
		TreeRow.FullName     = SubsystemMetadata.FullName();
		TreeRow.Presentation = SubsystemMetadata.Presentation();
		FullNamesArray.Add(TreeRow.FullName);
		If TreeRowsFullNames[TreeRow.FullName] = Undefined Then
			TreeRowsFullNames.Insert(TreeRow.FullName, TreeRow);
		Else
			TreeRowsFullNames.Insert(TreeRow.FullName, True); // A search in the tree is required.
		EndIf;
		TreeRow.SectionFullName = ParentLevelRow.SectionFullName;
		
		If StrLen(ParentPriority) > 12 Then
			TreeRow.FullPresentation = ParentLevelRow.Presentation + ": " + TreeRow.Presentation;
		Else
			TreeRow.FullPresentation = TreeRow.Presentation;
		EndIf;
		TreeRow.Priority = ParentPriority + Format(Priority, "ND=4; NFD=0; NLZ=; NG=0");
		
		AddCurrentUserSubsystems(TreeRow, SubsystemMetadata, FullNamesArray, TreeRowsFullNames);
	EndDo;
EndProcedure

// Returns True if the user has the right to read report options.
Function ReadRight() Export
	Return AccessRight("Read", Metadata.Catalogs.ReportsOptions);
EndFunction

// Returns True if the user has the right to save report options.
Function InsertRight() Export
	Return AccessRight("SaveUserData", Metadata) AND AccessRight("Insert", Metadata.Catalogs.ReportsOptions);
EndFunction

// Subsystem parameters cached on update.
Function Parameters() Export
	FullSubsystemName = ReportsOptionsClientServer.FullSubsystemName();
	
	Parameters = StandardSubsystemsServer.ApplicationParameter(FullSubsystemName);
	If Parameters = Undefined Then
		ReportsOptions.ConfigurationCommonDataNonexclusiveUpdate(New Structure("SeparatedHandlers"));
		Parameters = StandardSubsystemsServer.ApplicationParameter(FullSubsystemName);
	EndIf;
	
	If ValueIsFilled(SessionParameters.ExtensionsVersion) Then
		ExtensionParameters = StandardSubsystemsServer.ExtensionParameter(FullSubsystemName);
		If ExtensionParameters = Undefined Then
			If Not Users.IsFullUser() Then
				SetPrivilegedMode(True);
				If Not PrivilegedMode() Then
					Raise NStr("ru = 'Не удалось обновить вспомогательные данные расширений. Обратитесь к администратору.'; en = 'Cannot update auxiliary extension data. Contact the administrator.'; pl = 'Nie udało się zaktualizować pomocnicze dane rozszerzeń. Zwróć się do administratora.';es_ES = 'No se ha podido actualizar los datos auxiliares de las extensiones. Diríjase al administrador.';es_CO = 'No se ha podido actualizar los datos auxiliares de las extensiones. Diríjase al administrador.';tr = 'Uzantıların yardımcı verileri yenilenemedi. Yöneticinize başvurun.';it = 'Impossibile aggiornare dati ausiliari dell''estensione. Contattare l''amministratore.';de = 'Die Zusatzdaten der Erweiterungen konnten nicht aktualisiert werden. Wenden Sie sich an den Administrator.'");
				EndIf;
			EndIf;
			Settings = New Structure;
			Settings.Insert("Configuration",      False);
			Settings.Insert("Extensions",        True);
			Settings.Insert("SharedData",       True);
			Settings.Insert("SeparatedData", True);
			Settings.Insert("Nonexclusive",       True);
			Settings.Insert("Deferred",        True);
			Settings.Insert("Full",            True);
			ReportsOptions.Refresh(Settings);
			ExtensionParameters = StandardSubsystemsServer.ExtensionParameter(FullSubsystemName);
		EndIf;
		If ExtensionParameters <> Undefined Then
			CommonClientServer.SupplementArray(Parameters.ReportsWithSettings, ExtensionParameters.ReportsWithSettings);
			CommonClientServer.SupplementTable(Parameters.FunctionalOptionsTable, ExtensionParameters.FunctionalOptionsTable);
		EndIf;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ModuleAdditionalReportsAndDataProcessors.OnDetermineReportsWithSettings(Parameters.ReportsWithSettings);
	EndIf;
	
	Return Parameters;
EndFunction

#EndRegion
