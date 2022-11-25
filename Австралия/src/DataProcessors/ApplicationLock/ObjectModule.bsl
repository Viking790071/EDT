#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

// Locks or unlocks the infobase, depending on the data processor attribute values.
// 
//
Procedure SetLock() Export
	
	ExecuteSetLock(DisableUserAuthorisation);
	
EndProcedure

// Disables the previously enabled session lock.
//
Procedure CancelLock() Export
	
	ExecuteSetLock(False);
	
EndProcedure

// Reads the infobase lock parameters and passes them to the data processor attributes.
// 
//
Procedure GetLockParameters() Export
	
	If Users.IsFullUser(, True) Then
		CurrentMode = GetSessionsLock();
		UnlockCode = CurrentMode.KeyCode;
	Else
		CurrentMode = IBConnections.GetDataAreaSessionLock();
	EndIf;
	
	DisableUserAuthorisation = CurrentMode.Use 
		AND (Not ValueIsFilled(CurrentMode.End) Or CurrentSessionDate() < CurrentMode.End);
	MessageForUsers = IBConnectionsClientServer.ExtractLockMessage(CurrentMode.Message);
	
	If DisableUserAuthorisation Then
		LockEffectiveFrom    = CurrentMode.Begin;
		LockEffectiveTo = CurrentMode.End;
	Else
		// If data lock is not set, most probably the form is opened by user in order to set the lock.
		// 
		// Therefore making lock date equal to the current date.
		LockEffectiveFrom     = BegOfMinute(CurrentSessionDate() + 5 * 60);
	EndIf;
	
EndProcedure

Procedure ExecuteSetLock(Value)
	
	If Users.IsFullUser(, True) Then
		Lock = New SessionsLock;
		Lock.KeyCode    = UnlockCode;
	Else
		Lock = IBConnections.NewConnectionLockParameters();
	EndIf;
	
	Lock.Begin           = LockEffectiveFrom;
	Lock.End            = LockEffectiveTo;
	Lock.Message        = IBConnections.GenerateLockMessage(MessageForUsers, 
		UnlockCode); 
	Lock.Use      = Value;
	
	If Users.IsFullUser(, True) Then
		SetSessionsLock(Lock);
	Else
		IBConnections.SetDataAreaSessionLock(Lock);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf