#Region Private

// Notifies that bank classifier needs updating.
//
Procedure BankManagerDisplayObsoleteDataWarning() Export
	BankManagerClient.NotifyClassifierObsolete();
EndProcedure

#EndRegion
