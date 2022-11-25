#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

// Adds a record to the register by the passed structure values.
Procedure AddRecord(RecordStructure) Export
	
	If Common.DataSeparationEnabled()
		AND Common.SeparatedDataUsageAvailable() Then
		
		DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "DataAreasSuccessfulDataExchangeStates");
	Else
		DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "SuccessfulDataExchangesStates");
	EndIf;
	
EndProcedure

#EndRegion

#EndIf