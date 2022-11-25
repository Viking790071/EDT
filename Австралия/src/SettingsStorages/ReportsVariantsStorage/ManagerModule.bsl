#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

// Reading handler of report option settings.
//
// Parameters:
//   ReportKey        - String - a full name of a report with a point.
//   OptionKey      - String - Report option key.
//   Settings         - Arbitrary     - report option settings.
//   SettingsDetails  - SettingsDetails - Additional details of settings.
//   User      - String           - a name of an infobase user.
//       It is not used, because the "Report options" subsystem does not separate options by their authors.
//       The uniqueness of storage and selection is guaranteed by the uniqueness of pairs of report and options keys .
//
// See also:
//   "SettingsStorageManager.<Storage name>.LoadProcessing" in Syntax Assistant.
//
Procedure LoadProcessing(ObjectKey, SettingsKey, Settings, SettingsDescription, User)
	If Not ReportsOptionsCached.ReadRight() Then
		Return;
	EndIf;
	
	If TypeOf(ObjectKey) = Type("String") Then
		ReportInformation = ReportsOptions.GenerateReportInformationByFullName(ObjectKey);
		If TypeOf(ReportInformation.ErrorText) = Type("String") Then
			Raise ReportInformation.ErrorText;
		EndIf;
		ReportRef = ReportInformation.Report;
	Else
		ReportRef = ObjectKey;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED TOP 1
	|	ReportsOptions.Description,
	|	ReportsOptions.Settings
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|WHERE
	|	ReportsOptions.Report = &Report
	|	AND ReportsOptions.VariantKey = &VariantKey";
	Query.SetParameter("Report",        ReportRef);
	Query.SetParameter("VariantKey", SettingsKey);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		If SettingsDescription = Undefined Then
			SettingsDescription = New SettingsDescription;
			SettingsDescription.ObjectKey  = ObjectKey;
			SettingsDescription.SettingsKey = SettingsKey;
			SettingsDescription.User = User;
		EndIf;
		SettingsDescription.Presentation = Selection.Description;
		Settings = Selection.Settings.Get();
	EndIf;
EndProcedure

// Handler of writing report option settings.
//
// Parameters:
//   ReportKey        - String - a full name of a report with a point.
//   OptionKey      - String - Report option key.
//   Settings         - Arbitrary         - report option settings.
//   SettingsDetails  - SettingsDetails     - Additional details of settings.
//   User      - String, Undefined - a name of an infobase user.
//       It is not used, because the "Report options" subsystem does not separate options by their authors.
//       The uniqueness of storage and selection is guaranteed by the uniqueness of pairs of report and options keys .
//
// See also:
//   "SettingsStorageManager.<Storage name>.SaveProcessing" in Syntax Assistant.
//
Procedure SaveProcessing(ObjectKey, SettingsKey, Settings, SettingsDescription, User)
	If Not ReportsOptionsCached.InsertRight() Then
		Raise NStr("ru = 'Insufficient rights to save report options.'; en = 'Insufficient rights to save report options.'; pl = 'Insufficient rights to save report options.';es_ES = 'Insufficient rights to save report options.';es_CO = 'Insufficient rights to save report options.';tr = 'Insufficient rights to save report options.';it = 'Insufficient rights to save report options.';de = 'Insufficient rights to save report options.'");
	EndIf;
	
	ReportInformation = ReportsOptions.GenerateReportInformationByFullName(ObjectKey);
	
	If TypeOf(ReportInformation.ErrorText) = Type("String") Then
		Raise ReportInformation.ErrorText;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	ReportsOptions.Ref
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|WHERE
	|	ReportsOptions.Report = &Report
	|	AND ReportsOptions.VariantKey = &VariantKey";
	Query.SetParameter("Report",        ReportInformation.Report);
	Query.SetParameter("VariantKey", SettingsKey);
	
	Selection = Query.Execute().Select();
	If Not Selection.Next() Then
		Return;
	EndIf;
	OptionRef = Selection.Ref;
	
	BeginTransaction();
	Try
		Lock = New DataLock;
		LockItem = Lock.Add(Metadata.Catalogs.ReportsOptions.FullName());
		LockItem.SetValue("Ref", OptionRef);
		Lock.Lock();
		
		OptionObject = OptionRef.GetObject();
		If TypeOf(Settings) = Type("DataCompositionSettings") Then // For a platform.
			Address = CommonClientServer.StructureProperty(Settings.AdditionalProperties, "Address");
			If TypeOf(Address) = Type("String") AND IsTempStorageURL(Address) Then
				Settings = GetFromTempStorage(Address);
			EndIf;
		EndIf;
		OptionObject.Settings = New ValueStorage(Settings);
		If SettingsDescription <> Undefined Then
			OptionObject.Description = SettingsDescription.Presentation;
		EndIf;
		OptionObject.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Receiving handler of report option settings details.
//
// Parameters:
//   ReportKey       - String - a full name of a report with a point.
//   OptionKey     - String - Report option key.
//   SettingsDetails - SettingsDetails     - Additional details of settings.
//   User     - String, Undefined - a name of an infobase user..
//       It is not used, because the "Report options" subsystem does not separate options by their authors.
//       The uniqueness of storage and selection is guaranteed by the uniqueness of pairs of report and options keys .
//
// See also:
//   "SettingsStorageManager.<Storage name>.GetDescriptionProcessing" in Syntax Assistant.
//
Procedure GetDescriptionProcessing(ObjectKey, SettingsKey, SettingsDescription, User)
	If Not ReportsOptionsCached.ReadRight() Then
		Return;
	EndIf;
	
	If TypeOf(ObjectKey) = Type("String") Then
		ReportInformation = ReportsOptions.GenerateReportInformationByFullName(ObjectKey);
		If TypeOf(ReportInformation.ErrorText) = Type("String") Then
			Raise ReportInformation.ErrorText;
		EndIf;
		ReportRef = ReportInformation.Report;
	Else
		ReportRef = ObjectKey;
	EndIf;
	
	If SettingsDescription = Undefined Then
		SettingsDescription = New SettingsDescription;
	EndIf;
	
	SettingsDescription.ObjectKey  = ObjectKey;
	SettingsDescription.SettingsKey = SettingsKey;
	
	If TypeOf(User) = Type("String") Then
		SettingsDescription.User = User;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED TOP 1
	|	Variants.Presentation AS Presentation,
	|	Variants.DeletionMark,
	|	Variants.Custom
	|FROM
	|	Catalog.ReportsOptions AS Variants
	|WHERE
	|	Variants.Report = &Report
	|	AND Variants.VariantKey = &VariantKey";
	Query.SetParameter("Report",        ReportRef);
	Query.SetParameter("VariantKey", SettingsKey);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		SettingsDescription.Presentation = Selection.Presentation;
		SettingsDescription.AdditionalProperties.Insert("DeletionMark", Selection.DeletionMark);
		SettingsDescription.AdditionalProperties.Insert("Custom", Selection.Custom);
	EndIf;
EndProcedure

// Installation handler of report option settings details.
//
// Parameters:
//   ReportKey       - String - a full name of a report with a point.
//   OptionKey     - String - Report option key.
//   SettingsDetails - SettingsDetails - Additional details of settings.
//   User     - String           - a name of an infobase user.
//       It is not used, because the "Report options" subsystem does not separate options by their authors.
//       The uniqueness of storage and selection is guaranteed by the uniqueness of pairs of report and options keys .
//
// See also:
//   "SettingsStorageManager.<Storage name>.SetDescriptionProcessing" in Syntax Assistant.
//
Procedure SetDescriptionProcessing(ObjectKey, SettingsKey, SettingsDescription, User)
	If Not ReportsOptionsCached.InsertRight() Then
		Raise NStr("ru = 'Insufficient rights to save report options.'; en = 'Insufficient rights to save report options.'; pl = 'Insufficient rights to save report options.';es_ES = 'Insufficient rights to save report options.';es_CO = 'Insufficient rights to save report options.';tr = 'Insufficient rights to save report options.';it = 'Insufficient rights to save report options.';de = 'Insufficient rights to save report options.'");
	EndIf;
	
	If TypeOf(ObjectKey) = Type("String") Then
		ReportInformation = ReportsOptions.GenerateReportInformationByFullName(ObjectKey);
		If TypeOf(ReportInformation.ErrorText) = Type("String") Then
			Raise ReportInformation.ErrorText;
		EndIf;
		ReportRef = ReportInformation.Report;
	Else
		ReportRef = ObjectKey;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED TOP 1
	|	Variants.Ref
	|FROM
	|	Catalog.ReportsOptions AS Variants
	|WHERE
	|	Variants.Report = &Report
	|	AND Variants.VariantKey = &VariantKey";
	Query.SetParameter("Report",        ReportRef);
	Query.SetParameter("VariantKey", SettingsKey);
	
	Selection = Query.Execute().Select();
	If Not Selection.Next() Then
		Return;
	EndIf;
	OptionRef = Selection.Ref;
	
	BeginTransaction();
	Try
		Lock = New DataLock;
		LockItem = Lock.Add(Metadata.Catalogs.ReportsOptions.FullName());
		LockItem.SetValue("Ref", OptionRef);
		Lock.Lock();
		
		OptionObject = OptionRef.GetObject();
		OptionObject.Description = SettingsDescription.Presentation;
		OptionObject.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
EndProcedure

#EndRegion

#Region Private

Function GetList(ReportKey, Val User = Undefined) Export
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	Result = New ValueList;
	
	If TypeOf(ReportKey) = Type("String") Then
		ReportInformation = ReportsOptions.GenerateReportInformationByFullName(ReportKey);
		If TypeOf(ReportInformation.ErrorText) = Type("String") Then
			Raise ReportInformation.ErrorText;
		EndIf;
		ReportRef = ReportInformation.Report;
	Else
		ReportRef = ReportKey;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED DISTINCT
	|	Variants.VariantKey,
	|	Variants.Description
	|FROM
	|	Catalog.ReportsOptions AS Variants
	|WHERE
	|	Variants.Report = &Report
	|	AND Variants.Author = &Author
	|	AND Variants.Author.IBUserID = &GUID
	|	AND Variants.DeletionMark = FALSE
	|	AND Variants.Custom = TRUE";
	Query.SetParameter("Report", ReportRef);
	
	If User = "" Then
		User = Users.UnspecifiedUserRef();
	ElsIf User = Undefined Then
		User = Users.AuthorizedUser();
	EndIf;
	
	If TypeOf(User) = Type("CatalogRef.Users") Then
		Query.SetParameter("Author", User);
		Query.Text = StrReplace(Query.Text, "AND Variants.Author.IBUserID = &GUID", "");
	Else
		If TypeOf(User) = Type("UUID") Then
			UserID = User;
		Else
			If TypeOf(User) = Type("String") Then
				SetPrivilegedMode(True);
				InfobaseUser = InfoBaseUsers.FindByName(User);
				SetPrivilegedMode(False);
				If InfobaseUser = Undefined Then
					Return Result;
				EndIf;
			ElsIf TypeOf(User) = Type("InfoBaseUser") Then
				InfobaseUser = User;
			Else
				Return Result;
			EndIf;
			UserID = InfobaseUser.UUID;
		EndIf;
		Query.SetParameter("GUID", UserID);
		Query.Text = StrReplace(Query.Text, "AND Variants.Author = &Author", "");
	EndIf;
	
	ReportOptionsTable = Query.Execute().Unload();
	For Each TableRow In ReportOptionsTable Do
		Result.Add(TableRow.VariantKey, TableRow.Description);
	EndDo;
	
	Return Result;
#EndIf
EndFunction

Procedure Delete(ReportKey, OptionKey, Val User) Export
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	
	QueryText = 
	"SELECT ALLOWED DISTINCT
	|	Variants.Ref
	|FROM
	|	Catalog.ReportsOptions AS Variants
	|WHERE
	|	Variants.Report = &Report
	|	AND Variants.Author = &Author
	|	AND Variants.Author.IBUserID = &GUID
	|	AND Variants.VariantKey = &VariantKey
	|	AND Variants.DeletionMark = FALSE
	|	AND Variants.Custom = TRUE";
	
	Query = New Query;
	
	If ReportKey = Undefined Then
		QueryText = StrReplace(QueryText, "Variants.Report = &Report", "TRUE");
	Else
		ReportInformation = ReportsOptions.GenerateReportInformationByFullName(ReportKey);
		If TypeOf(ReportInformation.ErrorText) = Type("String") Then
			Raise ReportInformation.ErrorText;
		EndIf;
		Query.SetParameter("Report", ReportInformation.Report);
	EndIf;
	
	If OptionKey = Undefined Then
		QueryText = StrReplace(QueryText, "AND Variants.VariantKey = &VariantKey", "");
	Else
		Query.SetParameter("VariantKey", OptionKey);
	EndIf;
	
	If User = "" Then
		User = Users.UnspecifiedUserRef();
	EndIf;
	
	If User = Undefined Then
		QueryText = StrReplace(QueryText, "AND Variants.Author = &Author", "");
		QueryText = StrReplace(QueryText, "AND Variants.Author.IBUserID = &GUID", "");
		
	ElsIf TypeOf(User) = Type("CatalogRef.Users") Then
		Query.SetParameter("Author", User);
		QueryText = StrReplace(QueryText, "AND Variants.Author.IBUserID = &GUID", "");
		
	Else
		If TypeOf(User) = Type("UUID") Then
			UserID = User;
		Else
			If TypeOf(User) = Type("String") Then
				SetPrivilegedMode(True);
				InfobaseUser = InfoBaseUsers.FindByName(User);
				SetPrivilegedMode(False);
				If InfobaseUser = Undefined Then
					Return;
				EndIf;
			ElsIf TypeOf(User) = Type("InfoBaseUser") Then
				InfobaseUser = User;
			Else
				Return;
			EndIf;
			UserID = InfobaseUser.UUID;
		EndIf;
		Query.SetParameter("GUID", UserID);
		QueryText = StrReplace(QueryText, "AND Variants.Author = &Author", "");
	EndIf;
	
	Query.Text = QueryText;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		OptionObject = Selection.Ref.GetObject();
		OptionObject.SetDeletionMark(True);
	EndDo;
	
#EndIf
EndProcedure

#EndRegion

#EndIf
