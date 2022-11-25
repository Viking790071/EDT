#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

Procedure AddRecord(RecordStructure) Export
	
	DataExchangeServer.AddRecordToInformationRegister(RecordStructure, "DataExchangeMessages");
	
EndProcedure

Procedure DeleteRecord(RecordStructure) Export
	
	DataExchangeServer.DeleteRecordSetFromInformationRegister(RecordStructure, "DataExchangeMessages");
	
EndProcedure

#EndRegion

#EndIf