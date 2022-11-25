#Region Public

// ID that is used for the home page in the ReportsOptionsOverridable module.
//
// Returns:
//   String - an ID that is used for the home page in the ReportsOptionsOverridable module.
//
Function HomePageID() Export
	
	Return "Subsystems";
	
EndFunction

#EndRegion

#Region Internal

// Adds Key to Structure if it is missing.
//
// Parameters:
//   Structure - Structure    - a structure to be complemented.
//   Key      - String       - a property name.
//   Value  - Arbitrary - optional. Property value if it is missing in the structure.
//
Procedure AddKeyToStructure(Structure, varKey, Value = Undefined) Export
	If Not Structure.Property(varKey) Then
		Structure.Insert(varKey, Value);
	EndIf;
EndProcedure

#EndRegion

#Region Private

// Subsystem presentation. It is used for writing to the event log and in other places.
Function SubsystemDescription(LanguageCode) Export
	Return NStr("ru = 'Варианты отчетов'; en = 'Report options'; pl = 'Opcje sprawozdania';es_ES = 'Opciones de informe';es_CO = 'Opciones de informe';tr = 'Rapor seçenekleri';it = 'Varianti di report';de = 'Berichtsoptionen'", ?(LanguageCode = Undefined, CommonClientServer.DefaultLanguageCode(), LanguageCode));
EndFunction

// Importance group presentation.
Function SeeAlsoPresentation() Export
	Return NStr("ru = 'См. также'; en = 'See also:'; pl = 'Patrz także';es_ES = 'Ver también';es_CO = 'Ver también';tr = 'Ayrıca bakınız';it = 'Guarda anche:';de = 'Siehe auch'");
EndFunction 

// Importance group presentation.
Function ImportantPresentation() Export
	Return NStr("ru = 'Важный'; en = 'Important'; pl = 'Ważne';es_ES = 'Importante';es_CO = 'Importante';tr = 'Önemli';it = 'Importante';de = 'Wichtig'");
EndFunction

// Notification event name to change a report option.
Function EventNameChangingOption() Export
	Return FullSubsystemName() + ".OptionEdit";
EndFunction

// Notification event name to change common settings.
Function EventNameChangingCommonSettings() Export
	Return FullSubsystemName() + ".CommonSettingsEdit";
EndFunction

// Short subsystem name.
Function SubsystemName()
	Return "ReportsOptions";
EndFunction

// Full subsystem name.
Function FullSubsystemName() Export
	Return "StandardSubsystems." + SubsystemName();
EndFunction

// Separator that is used on storing several descriptions in one string attribute.
Function StorageSeparator() Export
	Return Chars.LF;
EndFunction

// Separator that is used to display several descriptions in the interface.
Function PresentationSeparator() Export
	Return ", ";
EndFunction

// Converts a search string to an array of words with unique values sorted by length descending.
Function ParseSearchStringIntoWordArray(SearchString) Export
	WordsAndTheirLength = New ValueList;
	StringLength = StrLen(SearchString);
	
	Word = "";
	WordLength = 0;
	QuotationMarkOpened = False;
	For CharNumber = 1 To StringLength Do
		CharCode = CharCode(SearchString, CharNumber);
		If CharCode = 34 Then // 34 - a double quotation mark (").
			QuotationMarkOpened = Not QuotationMarkOpened;
		ElsIf QuotationMarkOpened
			Or (CharCode >= 48 AND CharCode <= 57) // Numbers.
			Or (CharCode >= 65 AND CharCode <= 90) // Uppercase Latin characters
			Or (CharCode >= 97 AND CharCode <= 122) // Lowercase Latin characters
			Or (CharCode >= 1040 AND CharCode <= 1103) // Cyrillic characters
			Or CharCode = 95 Then // "_" character
			Word = Word + Char(CharCode);
			WordLength = WordLength + 1;
		ElsIf Word <> "" Then
			If WordsAndTheirLength.FindByValue(Word) = Undefined Then
				WordsAndTheirLength.Add(Word, Format(WordLength, "ND=3; NLZ="));
			EndIf;
			Word = "";
			WordLength = 0;
		EndIf;
	EndDo;
	
	If Word <> "" AND WordsAndTheirLength.FindByValue(Word) = Undefined Then
		WordsAndTheirLength.Add(Word, Format(WordLength, "ND=3; NLZ="));
	EndIf;
	
	WordsAndTheirLength.SortByPresentation(SortDirection.Desc);
	
	Return WordsAndTheirLength.UnloadValues();
EndFunction

// The function converts a report type into a string ID.
Function ReportByStringType(Val ReportType, Val Report = Undefined) Export
	TypeOfReportType = TypeOf(ReportType);
	If TypeOfReportType = Type("String") Then
		Return ReportType;
	ElsIf TypeOfReportType = Type("EnumRef.ReportTypes") Then
		If ReportType = PredefinedValue("Enum.ReportTypes.Internal") Then
			Return "Internal";
		ElsIf ReportType = PredefinedValue("Enum.ReportTypes.Extension") Then
			Return "Extension";
		ElsIf ReportType = PredefinedValue("Enum.ReportTypes.Additional") Then
			Return "Additional";
		ElsIf ReportType = PredefinedValue("Enum.ReportTypes.External") Then
			Return "External";
		Else
			Return Undefined;
		EndIf;
	Else
		If TypeOfReportType <> Type("Type") Then
			ReportType = TypeOf(Report);
		EndIf;
		If ReportType = Type("CatalogRef.MetadataObjectIDs") Then
			Return "Internal";
		ElsIf ReportType = Type("CatalogRef.ExtensionObjectIDs") Then
			Return "Extension";
		ElsIf ReportType = Type("String") Then
			Return "External";
		Else
			Return "Additional";
		EndIf;
	EndIf;
EndFunction

// The function converts a report type into a string ID.
Function ReportType(ReportRef, ResultString = False) Export
	RefType = TypeOf(ReportRef);
	If RefType = Type("CatalogRef.MetadataObjectIDs") Then
		varKey = "Internal";
	ElsIf RefType = Type("CatalogRef.ExtensionObjectIDs") Then
		varKey = "Extension";
	ElsIf RefType = Type("String") Then
		varKey = "External";
	ElsIf RefType = AdditionalReportRefType() Then
		varKey = "Additional";
	Else
		varKey = ?(ResultString, Undefined, "EmptyRef");
	EndIf;
	Return ?(ResultString, varKey, PredefinedValue("Enum.ReportTypes." + varKey));
EndFunction

// Returns an additional report reference type.
Function AdditionalReportRefType() Export
	#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
		Exists = Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors");
	#Else
		Exists = CommonClient.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors");
	#EndIf
	If Exists Then
		Name = "AdditionalReportsAndDataProcessors";
		Return Type("CatalogRef." + Name);
	EndIf;
	Return Undefined;
EndFunction

#EndRegion
