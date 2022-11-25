////////////////////////////////////////////////////////////////////////////////
// Subsystem "IB version update".
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

#Region ProceduresUsedDuringTheDataExchange

// This procedure is the event handler WhenSendingDataToSubordinate.
//
// Parameters:
// see description of the OnSendDataToSubordinate event handler in the syntax helper.
// 
Procedure OnSubsystemsVersionsSending(DataItem, ItemSend, Val CreatingInitialImage = False) Export
	
	If ItemSend = DataItemSend.Delete
		OR ItemSend = DataItemSend.Ignore Then
		
		// Do not override standard data processor.
		
	ElsIf TypeOf(DataItem) = Type("InformationRegisterRecordSet.SubsystemsVersions") Then
		
		If CreatingInitialImage Then
			
						
		Else
			
			// Export the register only when you create initial image.
			ItemSend = DataItemSend.Ignore;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion
