///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Public

// Backward compatibility.
// Creates details of the message template parameter table.
//
// Returns:
//   ValueTable - a generated blank value table.
//    * ParameterName                - String - a parameter name.
//    * TypeDetails                - TypesDetails - parameter type details.
//    * IsPredefinedParameter - Boolean - indicates whether the parameter is predefined.
//    * ParameterPresentation      - String - a parameter presentation.
//
Function ParametersTable() Export
	
	TemplateParameters = New ValueTable;
	
	TemplateParameters.Columns.Add("ParameterName"                , New TypeDescription("String",, New StringQualifiers(50, AllowedLength.Variable)));
	TemplateParameters.Columns.Add("TypeDetails"                , New TypeDescription("TypeDescription"));
	TemplateParameters.Columns.Add("IsPredefinedParameter" , New TypeDescription("Boolean"));
	TemplateParameters.Columns.Add("ParameterPresentation"      , New TypeDescription("String",, New StringQualifiers(150, AllowedLength.Variable)));
	
	Return TemplateParameters;
	
EndFunction

#EndRegion
