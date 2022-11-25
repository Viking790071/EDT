#Region Public

// Is called when deleting the data area.
// All data areas that cannot be deleted in the standard way must be deleted in this procedure.
// 
//
// Parameters:
//   DataArea - Number - value of the separator of the data area to be deleted.
// 
Procedure DataAreaOnDelete(Val DataArea) Export
	
EndProcedure

// Generates the list of infobase parameters.
//
// Parameters:
//   ParametersTable - ValueTable - infobase parameter details, see SaaS.GetIBParametersTable(). 
//
Procedure OnFillIIBParametersTable(Val ParametersTable) Export
	
EndProcedure

// The procedure is called before an attempt to get the infobase parameter values from the constants 
// with the same name.
//
// Parameters:
//   ParameterNames - Array - parameter names whose values are to be received.
//     If the parameter value is received in this procedure, the processed parameter name must be 
//     removed from the array.
//   ParameterValues - Structure - parameter values.
//
Procedure OnGetIBParametersValues(Val ParametersNames, Val ParameterValues) Export
	
EndProcedure

// Is called before an attempt to write infobase parameters as constants with the same name.
// 
//
// Parameters:
//   ParameterValues - Structure - parameter values to be set.
//     If the parameter value is set in the procedure based on structure, the corresponding 
//     KeyAndValue pair must be deleted.
//
Procedure OnSetIBParametersValues(Val ParameterValues) Export
	
EndProcedure

// The procedure is called when enabling the data separation, during the first start of the 
// configuration with "InitializeSeparatedIB" parameter.
// 
// Place code here to enable scheduled jobs used only when data separation is enabled and to disable 
// jobs used only when data separation is disabled.
// 
//
Procedure OnEnableSeparationByDataAreas() Export
	
	
EndProcedure

// Provides the user with the default rights.
// Is called in the SaaS mode if rights of a user who is not an administrator is changed.
// 
//
// Parameters:
//  User - CatalogRef.Users - user whose default rights to be set.
//   
//
Procedure SetDefaultRights(User) Export
	
	
	
EndProcedure

#EndRegion
