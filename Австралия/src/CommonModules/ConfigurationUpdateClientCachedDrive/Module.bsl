#Region ProgramInterface


// It returns the structure of
// the parameters necessary for the configuration work on the client.
// 
// Returns:
//   FixedStructure - structure of the client work parameters on start.
//                           
Function ClientWorkParameters() Export
	
	CurrentDate = DriveReUse.GetSessionCurrentDate(); // Current date of the client computer.
	
	ClientWorkParameters = New Structure;
	WorkParameters = ConfigurationUpdateServerCallDrive.ClientWorkParameters();
	For Each Parameter In WorkParameters Do
		ClientWorkParameters.Insert(Parameter.Key, Parameter.Value);
	EndDo;
	ClientWorkParameters.SessionTimeOffset = ClientWorkParameters.SessionTimeOffset - CurrentDate;
	
	Return New FixedStructure(ClientWorkParameters);
	
EndFunction

#EndRegion
