#Region Public

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for the SuppliedData subsystem the SuppliedDataOverridable common module .
// 
//

// Registers supplied data handlers.
//
// When a new shared data notification is received procedures are called.
// NewDataAvailable from modules registered with GetSuppliedDataHandlers.
// Descriptor - XDTODataObject Descriptor passed to the procedure.
// 
// If NewDataAvailable sets Import to True, the data is imported, and the descriptor and the path to 
// the data file are passed to the procedure.
// ProcessNewData. The file is automatically deleted once the procedure is executed.
// If the file is not specified in Service Manager, the parameter value is Undefined.
//
// Parameters:
//   Handlers - ValueTable - table for adding handlers with the following columns:
//     * DataKind - String - code of the data kind processed by the handler.
//     * HandlerCode - Sting - used for recovery after a data processing error.
//     * Handler - CommonModule - module contains the following procedures:
//		  	NewDataAvailable(Descriptor, Import) Export
//			ProcessNewData(Descriptor, PathToFile) Export
//			DataProcessingCanceled(Descriptor) Export
//
Procedure GetSuppliedDataHandlers(Handlers) Export
	
	
	
EndProcedure

#EndRegion
