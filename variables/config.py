"""Day 17 - a dynamic variable file: one config per environment.

get_variables() is the hook Robot looks for. Whatever dict it returns becomes
suite variables, so ${BASE_URL} exists without being written in any .robot file.

    Variables    ../variables/config.py           -> dev (the default below)
    Variables    ../variables/config.py    staging
    robot --variablefile variables/config.py:staging tests/

Why a .py and not a *** Variables *** table: the table cannot branch. Here the
same suite runs against dev or staging by changing one argument - which is
exactly what CI needs.

Day 30 note: the URLs below are illustration, not configuration. No suite
navigates to them any more - the web tests get their base URL at runtime from
libraries/PageServer.py, because a server on a free port has no address to
write down in advance. What tests/17_external_test_data.robot checks here is the
mechanism, not the values.
"""

ENVIRONMENTS = {
    "dev": {
        "BASE_URL": "https://the-internet.herokuapp.com",
        "API_URL": "https://jsonplaceholder.typicode.com",
        "TIMEOUT": "10s",
    },
    "staging": {
        "BASE_URL": "https://staging.the-internet.herokuapp.com",
        "API_URL": "https://staging.jsonplaceholder.typicode.com",
        "TIMEOUT": "30s",
    },
}


def get_variables(env: str = "dev") -> dict:
    """Returns the variables for one environment.

    Failing loudly on an unknown name beats silently running the whole suite
    against an empty URL.
    """
    if env not in ENVIRONMENTS:
        known = ", ".join(sorted(ENVIRONMENTS))
        raise ValueError(f"Unknown environment {env!r}. Known: {known}")
    return {"ENV": env, **ENVIRONMENTS[env]}
