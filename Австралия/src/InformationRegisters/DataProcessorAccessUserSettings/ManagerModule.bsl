#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

// Writes the table of settings to the registry data for the specified measurements.
Procedure WriteSettingsPackage(SettingsTable, MeasurementsValues, ResourcesValues, DeleteOldItems) Export
	
	RecordSet = CreateRecordSet();
	For Each KeyAndValue In MeasurementsValues Do
		RecordSet.Filter[KeyAndValue.Key].Set(KeyAndValue.Value, True);
		SettingsTable.Columns.Add(KeyAndValue.Key);
		SettingsTable.FillValues(KeyAndValue.Value, KeyAndValue.Key);
	EndDo;
	For Each KeyAndValue In ResourcesValues Do
		SettingsTable.Columns.Add(KeyAndValue.Key);
		SettingsTable.FillValues(KeyAndValue.Value, KeyAndValue.Key);
	EndDo;
	If Not DeleteOldItems Then
		RecordSet.Read();
		OldRecords = RecordSet.Unload();
		MeasurementsSearch = New Structure("AdditionalReportOrDataProcessor, CommandID, User");
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

#EndRegion

#EndIf