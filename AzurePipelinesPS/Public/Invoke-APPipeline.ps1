function Invoke-APPipeline
{
    <#
    .SYNOPSIS

    Queues a pipeline run by pipeline id.

    .DESCRIPTION

    Queues a pipeline run by pipeline id.
    The id can be returned using Get-APPipelineList.

    .PARAMETER Instance
    
    The Team Services account or TFS server.
    
    .PARAMETER Collection
    
    For Azure DevOps the value for collection should be the name of your orginization. 
    For both Team Services and TFS The value should be DefaultCollection unless another collection has been created.

    .PARAMETER Project
    
    Project ID or project name.

    .PARAMETER ApiVersion
    
    Version of the api to use.

    .PARAMETER PersonalAccessToken
    
    Personal access token used to authenticate that has been converted to a secure string. 
    It is recomended to uses an Azure Pipelines PS session to pass the personal access token parameter among funcitons, See New-APSession.
    https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=vsts
    
    .PARAMETER Credential

    Specifies a user account that has permission to send the request.

    .PARAMETER Proxy
    
    Use a proxy server for the request, rather than connecting directly to the Internet resource. Enter the URI of a network proxy server.

    .PARAMETER ProxyCredential
    
    Specifie a user account that has permission to use the proxy server that is specified by the -Proxy parameter. The default is the current user.

    .PARAMETER Session

    Azure DevOps PS session, created by New-APSession.

    .PARAMETER PipelineId

    The id of an existing pipeline. 

    .PARAMETER PipelineVersion

    The version of the pipeline to queue.

    .PARAMETER PreviewRun

    If true, don't actually create a new run. Instead returen the final YAML document after parsing templates.

    .PARAMETER Resources

    The resources the run requires.

    .PARAMETER StagesToSkip

    The stages to skip.

    .PARAMETER TemplateParameters

    Runtime parameters to pass to the pipeline.

    .PARAMETER Variables

    Pipeline variables.

    .PARAMETER YamlOverride

    If you use the preview run option, you may optionally supply different YAML. This allows you to preview the final YAML document without committing a changed file.

    .INPUTS
    
    None, does not support pipeline.

    .OUTPUTS

    None

    .EXAMPLE
    $resources = @{
    repositories = @{
            self = @{
                refName = 'refs/heads/feature/myFeature'
            }
        }
    }
    $stagesToSkip = @(
        'Test_Build'
        'Test_Deployment'
    )
    Invoke-APPipeline -Session 'mySession -PipelineId 7 -Resources $resources -StagesToSkip $stagesToSkip

    .LINK
    
    https://docs.microsoft.com/en-us/rest/api/azure/devops/pipelines/runs/run%20pipeline?view=azure-devops-rest-6.0
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByPersonalAccessToken')]
    Param
    (
        [Parameter(Mandatory,
            ParameterSetName = 'ByPersonalAccessToken')]
        [Parameter(Mandatory,
            ParameterSetName = 'ByCredential')]
        [uri]
        $Instance,

        [Parameter(Mandatory,
            ParameterSetName = 'ByPersonalAccessToken')]
        [Parameter(Mandatory,
            ParameterSetName = 'ByCredential')]
        [string]
        $Collection,

        [Parameter(Mandatory,
            ParameterSetName = 'ByPersonalAccessToken')]
        [Parameter(Mandatory,
            ParameterSetName = 'ByCredential')]
        [string]
        $Project,

        [Parameter(Mandatory,
            ParameterSetName = 'ByPersonalAccessToken')]
        [Parameter(Mandatory,
            ParameterSetName = 'ByCredential')]
        [string]
        $ApiVersion,

        [Parameter(ParameterSetName = 'ByPersonalAccessToken')]
        [Security.SecureString]
        $PersonalAccessToken,

        [Parameter(ParameterSetName = 'ByCredential')]
        [pscredential]
        $Credential,

        [Parameter(ParameterSetName = 'ByPersonalAccessToken')]
        [Parameter(ParameterSetName = 'ByCredential')]
        [string]
        $Proxy,

        [Parameter(ParameterSetName = 'ByPersonalAccessToken')]
        [Parameter(ParameterSetName = 'ByCredential')]
        [pscredential]
        $ProxyCredential,

        [Parameter(Mandatory,
            ParameterSetName = 'BySession')]
        [object]
        $Session,

        [Parameter(Mandatory)]
        [int]
        $PipelineId,
        
        [Parameter()]
        [int]
        $PipelineVersion,

        [Parameter()]
        [bool]
        $PreviewRun,

        [Parameter()]
        [object]
        $Resources,

        [Parameter()]
        [string[]]
        $StagesToSkip,

        [Parameter()]
        [hashtable]
        $TemplateParameters,

        [Parameter()]
        [hashtable]
        $Variables,

        [Parameter()]
        [string]
        $YamlOverride
    )

    begin
    {
        If ($PSCmdlet.ParameterSetName -eq 'BySession')
        {
            $currentSession = $Session | Get-APSession
            If ($currentSession)
            {
                $Instance = $currentSession.Instance
                $Collection = $currentSession.Collection
                $Project = $currentSession.Project
                $PersonalAccessToken = $currentSession.PersonalAccessToken
                $Credential = $currentSession.Credential
                $Proxy = $currentSession.Proxy
                $ProxyCredential = $currentSession.ProxyCredential
                If ($currentSession.Version)
                {
                    $ApiVersion = (Get-APApiVersion -Version $currentSession.Version)
                }
                else
                {
                    $ApiVersion = $currentSession.ApiVersion
                }
            }
        }
    }
    
    process
    {
        $body = @{
            PreviewRun = $PreviewRun
        }
        If ($PipelineVersion)
        {
            $body.PipelineVersion = $PipelineVersion
        }
        If ($Resources)
        {
            $body.resources = $Resources
        }
        If ($StagesToSkip)
        {
            $body.stagesToSkip = $StagesToSkip
        }
        If ($TemplateParameters)
        {
            $body.templateParameters = $TemplateParameters
        }
        If ($Variables)
        {
            $body.variables = $Variables
        }
        If ($YamlOverride)
        {
            $body.yamlOverride = $YamlOverride
        }
        $apiEndpoint = (Get-APApiEndpoint -ApiType 'pipelines-runs') -f $PipelineId
        $setAPUriSplat = @{
            Collection  = $Collection
            Instance    = $Instance
            Project     = $Project
            ApiVersion  = $ApiVersion
            ApiEndpoint = $apiEndpoint
        }
        [uri] $uri = Set-APUri @setAPUriSplat
        $invokeAPRestMethodSplat = @{
            ContentType         = 'application/json'
            Body                = $body
            Method              = 'POST'
            Uri                 = $uri
            Credential          = $Credential
            PersonalAccessToken = $PersonalAccessToken
            Proxy               = $Proxy
            ProxyCredential     = $ProxyCredential
        }
        $results = Invoke-APRestMethod @invokeAPRestMethodSplat 
        If ($results.value)
        {
            return $results.value
        }
        else
        {
            return $results
        }
    }
    
    end
    {
    }
}