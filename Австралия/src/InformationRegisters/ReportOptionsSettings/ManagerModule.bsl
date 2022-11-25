#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.AccessManagement

// See AccessManagementOverridable.OnFillListsWithAccessRestriction. 
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.Text =
	"AllowReadUpdate
	|WHERE
	|	IsAuthorizedUser(User)
	|	OR IsAuthorizedUser(Variant.Author)";
	
	Restriction.TextForExternalUsers = Restriction.Text;
	
EndProcedure

// End StandardSubsystems.AccessManagement

#EndRegion

#EndRegion

#Region Private

// Writes the table of settings to the registry data for the specified measurements.
Procedure WriteSettingsPackage(SettingsTable, Dimensions, Resources, DeleteOldItems) Export
	
	RecordSet = CreateRecordSet();
	For Each KeyAndValue In Dimensions Do
		RecordSet.Filter[KeyAndValue.Key].Set(KeyAndValue.Value, True);
		SettingsTable.Columns.Add(KeyAndValue.Key);
		SettingsTable.FillValues(KeyAndValue.Value, KeyAndValue.Key);
	EndDo;
	For Each KeyAndValue In Resources Do
		SettingsTable.Columns.Add(KeyAndValue.Key);
		SettingsTable.FillValues(KeyAndValue.Value, KeyAndValue.Key);
	EndDo;
	If Not DeleteOldItems Then
		RecordSet.Read();
		OldRecords = RecordSet.Unload();
		MeasurementsSearch = New Structure("User, Subsystem, Variant");
		For Each OldRecord In OldRecords Do
			FillPropertyValues(MeasurementsSearch, OldRecord);
			If SettingsTable.FindRows(MeasurementsSearch).Count() = 0 Then
				FillPropertyValues(SettingsTable.Add(), OldRecord);
			EndIf;
		EndDo;
	EndIf;
	RecordSet.Load(SettingsTable);
	RecordSet.Write(True);
	
EndProcedure

// Clears settings by a report option.
Procedure ClearSettings(OptionRef = Undefined) Export
	
	RecordSet = CreateRecordSet();
	If OptionRef <> Undefined Then
		RecordSet.Filter.Variant.Set(OptionRef, True);
	EndIf;
	RecordSet.Write(True);
	
EndProcedure

// Clears settings of the specified (of the current) user in the section.
Procedure ResetUserSettingsInSection(SectionRef, User = Undefined) Export
	If User = Undefined Then
		User = Users.AuthorizedUser();
	EndIf;
	
	Query = New Query;
	Query.SetParameter("SectionRef", SectionRef);
	Query.Text =
	"SELECT ALLOWED DISTINCT
	|	MetadataObjectIDs.Ref
	|FROM
	|	Catalog.MetadataObjectIDs AS MetadataObjectIDs
	|WHERE
	|	MetadataObjectIDs.Ref IN HIERARCHY(&SectionRef)";
	SubsystemsArray = Query.Execute().Unload().UnloadColumn("Ref");
	
	RecordSet = CreateRecordSet();
	RecordSet.Filter.User.Set(User, True);
	For Each SubsystemRef In SubsystemsArray Do
		RecordSet.Filter.Subsystem.Set(SubsystemRef, True);
		RecordSet.Write(True);
	EndDo;
EndProcedure

#EndRegion

#EndIf