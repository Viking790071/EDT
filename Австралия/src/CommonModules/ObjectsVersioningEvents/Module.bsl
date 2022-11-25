#Region Public

// Writes an object version (unless it is a document version) to the infobase.
//
// Parameters:
//  Source - Object - infobase object to be written;
//  Cancel    - Boolean - indicates whether the object record is canceled.
//
Procedure WriteObjectVersion(Source, Cancel) Export
	
	// Unconditional DataExchange.Load verification is not required because while writing the versioned 
	// object during the exchange it is necessary to save its current version in the version history.
	ObjectsVersioning.WriteObjectVersion(Source, False);
	
EndProcedure

// Writes a document version to the infobase.
//
// Parameters:
//  Source        - Object - infobase object to be written;
//  Cancel           - Boolean - flag specifying whether writing the document is canceled.
//  WriteMode     - DocumentWriteMode - specifies whether writing, posting, or canceling is performed.
//                                           Changing the parameter value modifies the write mode.
//  PostingMode - DocumentPostingMode - defines whether the real time posting is performed.
//                                               Changing the parameter value modifies the posting mode.
Procedure WriteDocumentVersion(Source, Cancel, WriteMode, PostingMode) Export
	
	// Unconditional DataExchange.Load verification is not required because while writing the versioned 
	// object during the exchange it is necessary to save its current version in the version history.
	ObjectsVersioning.WriteObjectVersion(Source, WriteMode);
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Event subscription handlers.

// For internal use only.
//
Procedure DeleteVersionAuthorInfo(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	InformationRegisters.ObjectsVersions.DeleteVersionAuthorInfo(Source.Ref);
	
EndProcedure

#EndRegion
