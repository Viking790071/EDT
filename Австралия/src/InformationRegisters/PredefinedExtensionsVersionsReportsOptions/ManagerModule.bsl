#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

// Writes the table of settings to the registry data for the specified measurements.
Function Set(SettingsTable, Dimensions, Resources, OverwriteExisting) Export
	
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
	If Not OverwriteExisting Then
		RecordSet.Read();
		OldRecords = RecordSet.Unload();
		MeasurementsSearch = New Structure("Report, Variant, ExtensionsVersion, VariantKey");
		For Each OldRecord In OldRecords Do
			FillPropertyValues(MeasurementsSearch, OldRecord);
			If SettingsTable.FindRows(MeasurementsSearch).Count() = 0 Then
				FillPropertyValues(SettingsTable.Add(), OldRecord);
			EndIf;
		EndDo;
	EndIf;
	RecordSet.Load(SettingsTable);
	Return RecordSet;
	
EndFunction

#EndRegion

#EndIf